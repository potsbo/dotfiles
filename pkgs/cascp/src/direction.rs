/// どちらのマシンで走らせるか。
#[derive(Clone, Copy, PartialEq)]
pub enum Side {
    Local,
    Remote,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub enum Direction {
    Pull,
    Push,
}

impl Direction {
    /// (送る側, 受け取る側)
    pub fn sides(self) -> (Side, Side) {
        match self {
            Direction::Pull => (Side::Remote, Side::Local),
            Direction::Push => (Side::Local, Side::Remote),
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
