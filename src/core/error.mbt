// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Why a call was refused.
///
/// The specification generates these on the device timeline and delivers them
/// to an error scope; this library runs the device timeline in the caller's
/// thread and raises them, which is the same information at the same point,
/// without a callback. The `kind` is the class the specification names, so a
/// caller can branch on it exactly as a browser test does.
pub suberror Refused {
  Validation(
    kind~ : @types.ErrorKind,
    at~ : String,
    want~ : String,
    got~ : String
  )
  OutOfMemory(at~ : String, limit~ : Int32, want~ : Int32)
  DeviceLost(reason~ : @types.DeviceLostReason)
  Internal(message~ : String)
}

///|
/// A validation error about one place in one descriptor.
pub fn invalid(
  kind : @types.ErrorKind,
  at : String,
  want : String,
  got : String,
) -> Refused {
  Validation(kind~, at~, want~, got~)
}

///|
/// The message a caller sees, carrying the same three fields the
/// specification's own messages carry.
pub fn Refused::message(self : Refused) -> String {
  match self {
    Validation(kind~, at~, want~, got~) =>
      "\{kind.name()} at \{at}: want \{want}, got \{got}"
    OutOfMemory(at~, limit~, want~) =>
      "out of memory at \{at}: limit \{limit}, want \{want}"
    DeviceLost(reason~) =>
      match reason {
        Unknown => "device lost (unknown)"
        Destroyed => "device lost (destroyed)"
      }
    Internal(message~) => "internal error: \{message}"
  }
}

///|
/// Raise `kind` unless `condition` holds.
pub fn require(
  condition : Bool,
  kind : @types.ErrorKind,
  at : String,
  want : String,
  got : String,
) -> Unit raise Refused {
  if !condition {
    raise invalid(kind, at, want, got)
  }
}

///|
/// Raise `kind` unless `want` and `got` are the same.
pub fn require_same(
  want : Int32,
  got : Int32,
  kind : @types.ErrorKind,
  at : String,
) -> Unit raise Refused {
  if want != got {
    raise invalid(kind, at, want.to_string(), got.to_string())
  }
}

///|
/// Raise `kind` unless `condition` holds, formatting the two values.
pub fn require_int(
  condition : Bool,
  kind : @types.ErrorKind,
  at : String,
  want : Int32,
  got : Int32,
) -> Unit raise Refused {
  if !condition {
    raise invalid(kind, at, want.to_string(), got.to_string())
  }
}

///|
/// The text of a flag set, for the `got` field of a refusal.
fn describe_usages(bits : UInt32, names : Array[(String, UInt32)]) -> String {
  let out = []
  for pair in names {
    let (name, bit) = pair
    if (bits & bit) != 0U {
      out.push(name)
    }
  }
  if out.is_empty() {
    "none"
  } else {
    out.join(" | ")
  }
}

///|
/// How a refusal reads to a caller of `createRenderPipelineAsync` and its
/// compute twin: `GPUPipelineError` carries a reason, and the two classes that
/// can resolve that promise are the ones this reports.
pub fn Refused::pipeline_reason(self : Refused) -> @types.PipelineErrorReason? {
  match self {
    Validation(..) => Some(@types.PipelineErrorReason::Validation)
    Internal(..) => Some(@types.PipelineErrorReason::Internal)
    _ => None
  }
}
