use crate::Result;
use crate::direction::Direction;

const USAGE: &str = "Usage: cascp [-r] host:path local\n       cascp [-r] local host:path";

#[derive(Debug, PartialEq)]
pub struct Args {
    pub recursive: bool,
    pub host: String,
    pub direction: Direction,
    pub src: String,
    pub dst: String,
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
    match (remote_endpoint(&src), remote_endpoint(&dst)) {
        (Some((host, src)), None) => Ok(Args {
            recursive,
            host,
            direction: Direction::Pull,
            src,
            dst,
        }),
        (None, Some((host, dst))) => Ok(Args {
            recursive,
            host,
            direction: Direction::Push,
            src,
            dst,
        }),
        (Some(_), Some(_)) => Err("copying between two remote hosts is not supported".into()),
        (None, None) => Err("one of source or destination must be host:path".into()),
    }
}

/// scp と同じ規則で host:path を見分ける: 最初の '/' より前に ':' があればリモート。
fn remote_endpoint(s: &str) -> Option<(String, String)> {
    let (host, path) = s.split_once(':')?;
    if host.is_empty() || host.contains('/') {
        return None;
    }
    // 相対パスはリモートの home から解決されるので、~ は外すだけでよい
    let path = match path {
        "" | "~" => ".",
        p => p.strip_prefix("~/").unwrap_or(p),
    };
    Some((host.to_string(), path.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn args(v: &[&str]) -> Result<Args> {
        parse_args(&v.iter().map(|s| s.to_string()).collect::<Vec<_>>())
    }

    #[test]
    fn remote_endpoint_follows_scp_rules() {
        assert_eq!(
            remote_endpoint("host:a/b"),
            Some(("host".into(), "a/b".into()))
        );
        assert_eq!(
            remote_endpoint("u@host:/abs"),
            Some(("u@host".into(), "/abs".into()))
        );
        assert_eq!(remote_endpoint("host:"), Some(("host".into(), ".".into())));
        assert_eq!(remote_endpoint("host:~"), Some(("host".into(), ".".into())));
        assert_eq!(
            remote_endpoint("host:~/x"),
            Some(("host".into(), "x".into()))
        );
        assert_eq!(remote_endpoint("./a:b"), None);
        assert_eq!(remote_endpoint("dir/a:b"), None);
        assert_eq!(remote_endpoint(":x"), None);
        assert_eq!(remote_endpoint("plain"), None);
    }

    #[test]
    fn parse_args_picks_direction() {
        let a = args(&["-r", "h:src", "dst"]).unwrap();
        assert_eq!(
            (a.direction, a.recursive, a.src.as_str(), a.dst.as_str()),
            (Direction::Pull, true, "src", "dst")
        );
        let a = args(&["src", "h:dst"]).unwrap();
        assert_eq!(
            (a.direction, a.recursive, a.src.as_str(), a.dst.as_str()),
            (Direction::Push, false, "src", "dst")
        );
        assert!(args(&["h:a", "g:b"]).is_err());
        assert!(args(&["a", "b"]).is_err());
        assert!(args(&["-p", "h:a", "b"]).is_err());
        assert!(args(&["h:a"]).is_err());
    }
}
