use crate::machine::Machine;
use crate::session::Session;

#[derive(Debug, PartialEq, Clone, Copy)]
pub enum Direction {
    Pull,
    Push,
}

impl Direction {
    /// (送る側, 受け取る側)
    pub fn sides(self, remote: &'static Session) -> (Machine, Machine) {
        match self {
            Direction::Pull => (Machine::Remote(remote), Machine::Local),
            Direction::Push => (Machine::Local, Machine::Remote(remote)),
        }
    }

    /// 足りない chunk を流すときの動詞と前置詞。
    pub fn verb(self) -> (&'static str, &'static str) {
        match self {
            Direction::Pull => ("Fetching", "from"),
            Direction::Push => ("Sending", "to"),
        }
    }
}
