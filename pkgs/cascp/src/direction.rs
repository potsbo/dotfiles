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
}
