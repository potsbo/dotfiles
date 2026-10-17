//! 1 回のコピーの流れ。どの手順もこのファイルを上から読めば追える。

use std::io::IsTerminal;
use std::path::Path;
use std::time::Instant;

use crate::Result;
use crate::chunk::{self, Sizes};
use crate::cli::Args;
use crate::direction::Side;
use crate::process::{lines, run};
use crate::script::{ASSEMBLE, CHUNK, INSPECT, MISSING, PREPARE, SIZES, TOUCH};
use crate::session::Session;
use crate::transfer::transfer;
use crate::ui::{step, warning};
use crate::units::{duration, human};

#[derive(Clone, Copy, PartialEq)]
enum Kind {
    Dir,
    File,
}

impl Kind {
    fn parse(s: &str) -> Result<Self> {
        match s {
            "dir" => Ok(Kind::Dir),
            "file" => Ok(Kind::File),
            _ => Err(format!("unexpected kind: {s}")),
        }
    }

    /// script の $1 に渡す名前。
    fn as_str(self) -> &'static str {
        match self {
            Kind::Dir => "dir",
            Kind::File => "file",
        }
    }
}

/// 送る側で INSPECT が返すもの。
struct Source {
    store: String,
    kind: Kind,
    mode: String,
    size: u64,
    nfiles: String,
}

impl Source {
    fn inspect(s: &Session, side: Side, path: &str) -> Result<Self> {
        let info = lines(&run(
            s.sh(side, INSPECT, &[path]),
            None,
            "inspecting source",
        )?);
        let [store, kind, mode, size, nfiles] = <[String; 5]>::try_from(info)
            .map_err(|l| format!("unexpected output while inspecting source: {l:?}"))?;
        Ok(Source {
            store,
            kind: Kind::parse(&kind)?,
            mode,
            size: size.parse().map_err(|_| format!("bad size: {size}"))?,
            nfiles,
        })
    }

    fn describe(&self) -> String {
        let mut desc = human(self.size);
        if self.kind == Kind::Dir {
            desc += &format!(", {} files", self.nfiles);
        }
        desc
    }
}

/// 受け取る側の (store, 実際に置く path)。
fn prepare(s: &Session, side: Side, dst: &str, base: &str) -> Result<(String, String)> {
    let prep = lines(&run(
        s.sh(side, PREPARE, &[dst, base]),
        None,
        "preparing destination",
    )?);
    let [store, dst] = <[String; 2]>::try_from(prep)
        .map_err(|l| format!("unexpected output while preparing destination: {l:?}"))?;
    Ok((store, dst))
}

/// chunk path の一覧を stdin に渡して script を走らせ、出力を行で返す。
fn with_chunks(
    s: &Session,
    side: Side,
    script: &str,
    paths: &[String],
    what: &str,
) -> Result<Vec<String>> {
    Ok(lines(&run(
        s.sh(side, script, &[]),
        Some(chunk::list(paths)),
        what,
    )?))
}

fn base_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map_or(path.to_string(), |n| n.to_string_lossy().into_owned())
}

pub fn copy(args: Args) -> Result<()> {
    let s = Session::open(&args.host)?;
    let (sender, receiver) = args.direction.sides();
    let bars = if std::io::stderr().is_terminal() {
        "1"
    } else {
        ""
    };

    let src = Source::inspect(s, sender, &args.src)?;
    if src.kind == Kind::Dir && !args.recursive {
        return Err(format!("{}: not a regular file", args.src));
    }
    let base = base_name(&args.src);
    let (rstore, dst) = prepare(s, receiver, &args.dst, &base)?;

    step(
        "Chunking",
        format!("{} ({})", s.display(sender, &args.src), src.describe()),
    );
    let t0 = Instant::now();
    let index = run(
        s.sh(sender, CHUNK, &[src.kind.as_str(), &args.src, bars]),
        None,
        "chunking",
    )?;
    let t_chunk = t0.elapsed().as_secs();

    let paths = chunk::paths(&index)?;
    let (missing, sizes) = if paths.is_empty() {
        (Vec::new(), Vec::new())
    } else {
        (
            with_chunks(s, receiver, MISSING, &paths, "checking cache")?,
            with_chunks(s, sender, SIZES, &paths, "measuring chunks")?,
        )
    };
    let Sizes { all, fetch } = Sizes::of(&paths, &sizes, &missing)?;
    let n_cached = paths.len() - missing.len();
    step(
        "Chunks",
        format!(
            "{} unique, {} compressed (chunked in {})",
            paths.len(),
            human(all),
            duration(t_chunk)
        ),
    );
    step(
        "Cached",
        format!(
            "{n_cached} chunks, {} ({}%)",
            human(all - fetch),
            n_cached * 100 / paths.len().max(1)
        ),
    );

    let t0 = Instant::now();
    if !missing.is_empty() {
        let (verb, prep) = args.direction.verb();
        step(
            verb,
            format!(
                "{} chunks, {} {prep} {}",
                missing.len(),
                human(fetch),
                s.host
            ),
        );
        transfer(
            s,
            s.rsync_path(sender, &src.store),
            s.rsync_path(receiver, &rstore),
            chunk::list(&missing),
            fetch,
        )?;
    }
    let t_transfer = t0.elapsed().as_secs();
    assemble(s, src, receiver, &dst, bars, index)?;

    touch(s, &paths, receiver, sender);

    step(
        "Finished",
        format!(
            "transferred {} of {} in {}",
            human(fetch),
            human(all),
            duration(t_transfer)
        ),
    );
    Ok(())
}

fn assemble(
    s: &Session,
    src: Source,
    receiver: Side,
    dst: &str,
    bars: &str,
    index: Vec<u8>,
) -> Result<()> {
    step("Assembling", s.display(receiver, dst));
    run(
        s.sh(
            receiver,
            ASSEMBLE,
            &[src.kind.as_str(), dst, &src.mode, bars],
        ),
        Some(index),
        "assembling",
    )?;
    Ok(())
}

fn touch(s: &Session, paths: &[String], receiver: Side, sender: Side) {
    // 記録が漏れても次の reap で消える順が変わるだけなので、転送の失敗にはしない
    if paths.is_empty() {
        return;
    }
    for side in [receiver, sender] {
        if let Err(e) = with_chunks(s, side, TOUCH, paths, "recording chunk use") {
            warning(e);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn base_names() {
        assert_eq!(base_name("/abc/def"), "def");
        assert_eq!(base_name("/abc/def/"), "def");
        assert_eq!(base_name("/"), "/");
        assert_eq!(base_name(""), "");
    }
}
