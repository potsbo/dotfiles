use crate::Result;

const USAGE: &str = "Usage: cascp [-r] host:path local\n       cascp [-r] local host:path\n       cascp [-r] local local";

/// 引数 1 つが指す場所。解析した時点ではまだつないでいないので、リモートはホストの名前しか
/// 持たない。つないで sh を走らせられるようにしたものが [`crate::machine::Machine`]
/// (`Machine::connect`)。
#[derive(Debug, PartialEq)]
pub enum Endpoint {
    Local(String),
    Remote { host: String, path: String },
}

impl Endpoint {
    /// scp と同じ規則で host:path を見分ける: 最初の '/' より前に ':' があればリモート。
    fn parse(s: &str) -> Self {
        let Some((host, path)) = s.split_once(':') else {
            return Endpoint::Local(s.to_string());
        };
        if host.is_empty() || host.contains('/') {
            return Endpoint::Local(s.to_string());
        }
        // 相対パスはリモートの home から解決されるので、~ は外すだけでよい
        let path = match path {
            "" | "~" => ".",
            p => p.strip_prefix("~/").unwrap_or(p),
        };
        Endpoint::Remote {
            host: host.to_string(),
            path: path.to_string(),
        }
    }

    /// その場所の上でのパス。
    pub fn path(&self) -> &str {
        match self {
            Endpoint::Local(path) | Endpoint::Remote { path, .. } => path,
        }
    }
}

#[derive(Debug, PartialEq)]
pub struct Args {
    pub recursive: bool,
    pub src: Endpoint,
    pub dst: Endpoint,
}

pub fn parse_args(argv: &[String]) -> Result<Args> {
    let mut recursive = false;
    let mut positional = Vec::new();
    for a in argv {
        match a.as_str() {
            "-r" => recursive = true,
            s if s.starts_with('-') && s.len() > 1 => return Err(format!("unknown option: {s}")),
            _ => positional.push(a.clone()),
        }
    }
    let [src, dst] = <[String; 2]>::try_from(positional).map_err(|_| USAGE.to_string())?;
    Ok(Args {
        recursive,
        src: Endpoint::parse(&src),
        dst: Endpoint::parse(&dst),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(v: &[&str]) -> Result<Args> {
        parse_args(&v.iter().map(|s| s.to_string()).collect::<Vec<_>>())
    }

    fn remote(host: &str, path: &str) -> Endpoint {
        Endpoint::Remote {
            host: host.into(),
            path: path.into(),
        }
    }

    fn local(path: &str) -> Endpoint {
        Endpoint::Local(path.into())
    }

    #[test]
    fn endpoint_follows_scp_rules() {
        assert_eq!(Endpoint::parse("host:a/b"), remote("host", "a/b"));
        assert_eq!(Endpoint::parse("u@host:/abs"), remote("u@host", "/abs"));
        assert_eq!(Endpoint::parse("host:"), remote("host", "."));
        assert_eq!(Endpoint::parse("host:~"), remote("host", "."));
        assert_eq!(Endpoint::parse("host:~/x"), remote("host", "x"));
        assert_eq!(Endpoint::parse("./a:b"), local("./a:b"));
        assert_eq!(Endpoint::parse("dir/a:b"), local("dir/a:b"));
        assert_eq!(Endpoint::parse(":x"), local(":x"));
        assert_eq!(Endpoint::parse("plain"), local("plain"));
    }

    #[test]
    fn parse_args_keeps_both_ends() {
        let a = args(&["-r", "h:src", "dst"]).unwrap();
        assert_eq!(
            (a.recursive, a.src, a.dst),
            (true, remote("h", "src"), local("dst"))
        );
        let a = args(&["src", "h:dst"]).unwrap();
        assert_eq!(
            (a.recursive, a.src, a.dst),
            (false, local("src"), remote("h", "dst"))
        );
        // どの組み合わせを扱うかは main が決める。ここでは両方リモートでも解析はできる
        let a = args(&["h:a", "g:b"]).unwrap();
        assert_eq!((a.src, a.dst), (remote("h", "a"), remote("g", "b")));
        assert!(args(&["-p", "h:a", "b"]).is_err());
        assert!(args(&["h:a"]).is_err());
    }
}
