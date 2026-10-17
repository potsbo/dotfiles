//! 1 回のコピーの流れ。どの手順もこのファイルを上から読めば追える。

use std::path::Path;
use std::time::Instant;

use crate::Result;
use crate::chunk::{self, Plan};
use crate::cli::Args;
use crate::machine::Machine;
use crate::process::{lines, run};
use crate::script::{ASSEMBLE, CHUNK, INSPECT, MISSING, PREPARE, SIZES, TOUCH};
use crate::session::Session;
use crate::transfer::transfer;
use crate::ui::{detail, step, warning};
use crate::units::{duration, human};

/// 送る元がファイルかディレクトリかと、その種類でだけ意味を持つ値。
/// INSPECT は種類によらず mode もファイル数も出すが、使い道があるほうだけを残す。
enum Kind {
    /// 組み立てた後に chmod で mode を戻す (ASSEMBLE の file の枝)。
    File { mode: String },
    /// ファイル数は表示だけに使う。ASSEMBLE の dir の枝 (desync untar) は mode を見ない。
    Dir { nfiles: u64 },
}

impl Kind {
    fn parse(kind: &str, mode: String, nfiles: &str) -> Result<Self> {
        match kind {
            "file" => Ok(Kind::File { mode }),
            "dir" => Ok(Kind::Dir {
                nfiles: nfiles
                    .trim()
                    .parse()
                    .map_err(|_| format!("bad file count: {nfiles}"))?,
            }),
            _ => Err(format!("unexpected kind: {kind}")),
        }
    }

    /// script の $1 に渡す名前。
    fn as_str(&self) -> &'static str {
        match self {
            Kind::File { .. } => "file",
            Kind::Dir { .. } => "dir",
        }
    }
}

/// 送る元。INSPECT で調べた結果を、どのマシンのどのパスかと一緒に持つ。
struct Source {
    machine: Machine,
    path: String,
    store: String,
    kind: Kind,
    /// 表示用の目安。ディレクトリは du の使用量なので概算。
    size: u64,
}

impl Source {
    fn inspect(machine: Machine, path: String) -> Result<Self> {
        let info = lines(&run(
            machine.sh(INSPECT, &[&path]),
            None,
            "inspecting source",
        )?);
        let [store, kind, mode, size, nfiles] = <[String; 5]>::try_from(info)
            .map_err(|l| format!("unexpected output while inspecting source: {l:?}"))?;
        Ok(Source {
            machine,
            path,
            store,
            kind: Kind::parse(&kind, mode, &nfiles)?,
            size: size.parse().map_err(|_| format!("bad size: {size}"))?,
        })
    }

    fn display(&self) -> String {
        self.machine.display(&self.path)
    }

    fn describe(&self) -> String {
        match self.kind {
            Kind::File { .. } => human(self.size),
            Kind::Dir { nfiles } => format!("{}, {nfiles} files", human(self.size)),
        }
    }

    /// chunk に切って store に入れ、index を返す。
    fn chunk(&self) -> Result<Vec<u8>> {
        run(
            self.machine.sh(CHUNK, &[self.kind.as_str(), &self.path]),
            None,
            "chunking",
        )
    }

    fn rsync_store(&self) -> String {
        self.machine.rsync_path(&self.store)
    }

    /// chunk の (圧縮後の) 大きさを `paths` と同じ順で返す。
    fn sizes(&self, paths: &[String]) -> Result<Vec<u64>> {
        with_chunks(self.machine, SIZES, paths, "measuring chunks")?
            .iter()
            .map(|v| v.trim().parse().map_err(|_| format!("bad chunk size: {v}")))
            .collect()
    }
}

/// 受け取る先。PREPARE で決めた実際に置くパスを、どのマシンかと一緒に持つ。
struct Destination {
    machine: Machine,
    store: String,
    path: String,
}

impl Destination {
    /// `base` は、`path` が既存ディレクトリだったときにその中に置く名前。
    fn prepare(machine: Machine, path: &str, base: &str) -> Result<Self> {
        let prep = lines(&run(
            machine.sh(PREPARE, &[path, base]),
            None,
            "preparing destination",
        )?);
        let [store, path] = <[String; 2]>::try_from(prep)
            .map_err(|l| format!("unexpected output while preparing destination: {l:?}"))?;
        Ok(Destination {
            machine,
            store,
            path,
        })
    }

    fn display(&self) -> String {
        self.machine.display(&self.path)
    }

    fn rsync_store(&self) -> String {
        self.machine.rsync_path(&self.store)
    }

    /// `paths` のうち store に無いもの。
    fn missing(&self, paths: &[String]) -> Result<Vec<String>> {
        with_chunks(self.machine, MISSING, paths, "checking cache")
    }

    /// `index` を store から組み立てる。
    fn assemble(&self, src: &Source, index: Vec<u8>) -> Result<()> {
        // ASSEMBLE の dir の枝は $3 を見ないので、何を渡してもよい
        let mode = match &src.kind {
            Kind::File { mode } => mode.as_str(),
            Kind::Dir { .. } => "",
        };
        run(
            self.machine
                .sh(ASSEMBLE, &[src.kind.as_str(), &self.path, mode]),
            Some(index),
            "assembling",
        )?;
        Ok(())
    }
}

/// 両端を調べて Source と Destination を作る。どちらのマシンが送る側かはここで決め、
/// copy() はマシンを意識しない。
fn endpoints(s: &'static Session, args: &Args) -> Result<(Source, Destination)> {
    let (from, to) = args.direction.sides(s);
    let src = Source::inspect(from, args.src.clone())?;
    // 受け取る側に触る前に断る (scp と同じく、-r 無しのディレクトリはエラー)
    if matches!(src.kind, Kind::Dir { .. }) && !args.recursive {
        return Err(format!("{}: not a regular file", src.path));
    }
    let dst = Destination::prepare(to, &args.dst, &base_name(&src.path))?;
    Ok((src, dst))
}

/// index から今回の Plan を立てる。受け取る側には何が無いかを、送る側にはそれぞれの
/// 大きさを聞く。
fn plan(src: &Source, dst: &Destination, index: &[u8]) -> Result<Plan> {
    let paths = chunk::paths(index)?;
    // chunk が 1 つも無い (空のファイルなど) なら聞くことがないので、往復を省く
    let plan = if paths.is_empty() {
        Plan::new(paths, Vec::new(), &[])?
    } else {
        let missing = dst.missing(&paths)?;
        let sizes = src.sizes(&paths)?;
        Plan::new(paths, missing, &sizes)?
    };
    let (head, details) = plan.report();
    step("Planned", head);
    for d in details {
        detail(d);
    }
    Ok(plan)
}

/// chunk path の一覧を stdin に渡して script を走らせ、出力を行で返す。
fn with_chunks(
    machine: Machine,
    script: &str,
    paths: &[String],
    what: &str,
) -> Result<Vec<String>> {
    Ok(lines(&run(
        machine.sh(script, &[]),
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
    let (src, dst) = endpoints(s, &args)?;

    let index = chunk(&src)?;
    let plan = plan(&src, &dst, &index)?;

    fill_missing(s, &plan, &src, &dst)?;
    assemble(&src, &dst, index)?;
    touch(&plan.paths, &src, &dst);

    Ok(())
}

fn chunk(src: &Source) -> Result<Vec<u8>> {
    let t0 = Instant::now();
    step(
        "Chunking",
        format!("{} ({})", src.display(), src.describe()),
    );
    let index = src.chunk()?;
    let t_chunk = t0.elapsed().as_secs();
    step("Chunked", format!("in {}", duration(t_chunk)));
    Ok(index)
}

/// 受け取る側に足りない chunk を、送る側の store から流し込む。かかった秒数を返す。
fn fill_missing(s: &Session, plan: &Plan, src: &Source, dst: &Destination) -> Result<()> {
    let t0 = Instant::now();
    if plan.missing.is_empty() {
        return Ok(());
    }
    step(
        "Transferring",
        format!("{} => {}", src.display(), dst.display()),
    );
    transfer(
        s,
        src.rsync_store(),
        dst.rsync_store(),
        chunk::list(&plan.missing),
        plan.fetch,
    )?;

    let t_transfer = t0.elapsed().as_secs();
    step(
        "Finished",
        format!(
            "transferred {} of {} in {}",
            human(plan.fetch),
            human(plan.all),
            duration(t_transfer)
        ),
    );
    Ok(())
}

/// chunk() で得た index を受け取る側で組み立てる。組み立ては転送の本体なので、touch と
/// 違って失敗はそのまま返す。
fn assemble(src: &Source, dst: &Destination, index: Vec<u8>) -> Result<()> {
    let t0 = Instant::now();
    step(
        "Assembling",
        format!("{} ({})", dst.display(), src.describe()),
    );
    dst.assemble(src, index)?;
    let t_assemble = t0.elapsed().as_secs();
    step("Assembled", format!("in {}", duration(t_assemble)));
    Ok(())
}

fn touch(paths: &[String], src: &Source, dst: &Destination) {
    // 記録が漏れても次の reap で消える順が変わるだけなので、転送の失敗にはしない
    if paths.is_empty() {
        return;
    }
    for machine in [dst.machine, src.machine] {
        if let Err(e) = with_chunks(machine, TOUCH, paths, "recording chunk use") {
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

    #[test]
    fn kind_keeps_only_what_its_variant_uses() {
        assert!(
            matches!(Kind::parse("file", "640".into(), "1"), Ok(Kind::File { mode }) if mode == "640")
        );
        // wc -l は BSD だと桁揃えの空白を前に付ける
        assert!(matches!(
            Kind::parse("dir", "755".into(), "      12"),
            Ok(Kind::Dir { nfiles: 12 })
        ));
        assert!(Kind::parse("dir", "755".into(), "many").is_err());
        assert!(Kind::parse("fifo", "644".into(), "1").is_err());
    }
}
