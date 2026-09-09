open Core

type t = {
  max_allowed_trades : int;
  mutable total_trades_sent : int;
  mutable kill_switch_engaged : bool;
}

let create ~max_trades = {
  max_allowed_trades = max_trades;
  total_trades_sent = 0;
  kill_switch_engaged = false;
}

(* Pre-trade validation check running in O(1) time *)
let validate_order (rm : t) : [ `Approve | `Reject of string ] =
  if rm.kill_switch_engaged then
    `Reject "KILL_SWITCH_ACTIVE"
  else if rm.total_trades_sent >= rm.max_allowed_trades then begin
    rm.kill_switch_engaged <- true; (* Auto-trip the fuse *)
    `Reject "MAX_TRADES_EXCEEDED_TRIPPING_CIRCUIT_BREAKER"
  end else begin
    rm.total_trades_sent <- rm.total_trades_sent + 1;
    `Approve
  end

