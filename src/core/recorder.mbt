// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// What one `CommandEncoder` has recorded so far.
///
/// The frame is a small state machine: a pass has to be ended before the next
/// command, and a finished encoder records nothing more. Both are rules of the
/// specification that a caller notices immediately, so both are refused at
/// once rather than at submit.
pub struct Frame {
  commands : Array[@types.Command]
  mut open : Bool
  mut finished : Bool
}

///|
/// An encoder that has recorded nothing.
pub fn Frame::new() -> Frame {
  { commands: [], open: false, finished: false, }
}

///|
/// The reason a command cannot be recorded right now.
fn Frame::refuse_if_busy(self : Frame, at : String) -> Unit raise Refused {
  require(
    !self.finished,
    @types.EncoderFinished,
    at,
    "an encoder that has not finished",
    "a finished encoder",
  )
  require(
    !self.open,
    @types.PassNotEnded,
    at,
    "a pass that has ended",
    "an open pass",
  )
}

///|
/// Refuse a command that arrives while a pass is open or after the encoder has
/// finished. Debug markers and other commands with no recorded effect still
/// have to obey these two rules.
pub fn Frame::check(self : Frame, at : String) -> Unit raise Refused {
  self.refuse_if_busy(at)
}

///|
/// Record a command that stands on its own, such as a copy or a clear.
pub fn Frame::record(
  self : Frame,
  command : @types.Command,
) -> Unit raise Refused {
  self.refuse_if_busy("encoder")
  self.commands.push(command)
}

///|
/// Mark the start of a pass.
pub fn Frame::open_pass(self : Frame) -> Unit raise Refused {
  self.refuse_if_busy("beginPass")
  self.open = true
}

///|
/// Mark the end of a pass and keep its recorded commands.
pub fn Frame::close_pass(
  self : Frame,
  command : @types.Command,
) -> Unit raise Refused {
  require(
    self.open,
    @types.InvalidPassState,
    "end",
    "a pass that started",
    "no open pass",
  )
  self.open = false
  self.commands.push(command)
}

///|
/// The command list, once the encoder is finished.
pub fn Frame::finish(self : Frame) -> Array[@types.Command] raise Refused {
  require(
    !self.open,
    @types.PassNotEnded,
    "finish",
    "a pass that has ended",
    "an open pass",
  )
  self.finished = true
  self.commands.copy()
}
