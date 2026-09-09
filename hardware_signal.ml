open Core
open Hardcaml

(* Define our circuit's input interfaces *)
module I = struct
  type 'a t = {
    clock          : 'a;
    available_size : 'a; [@bits 16] (* 16-bit hardware wire trace *)
    min_threshold  : 'a; [@bits 16]
  } [@@deriving sexp_of, hardcaml]
end

(* Define our circuit's output interfaces *)
module O = struct
  type 'a t = {
    trigger_trade  : 'a; [@bits 1]  (* 1-bit hardware execution line *)
  } [@@deriving sexp_of, hardcaml]
end

(* Pure circuit logic configuration using Hardcaml operators *)
let create_circuit (inputs : Signal.t I.t) =
  let open Signal in
  (* Compares the binary inputs directly on physical hardware wire paths *)
  let should_trigger = inputs.available_size >=: inputs.min_threshold in
  { O.trigger_trade = should_trigger }

(* The execution module that transforms OCaml logic to physical circuits *)
let generate_verilog () =
  printf "=== 🛠️ HARDCAML VERILOG GENERATION ENGINE 🛠️ ===\n";
  
  (* 1. Create a structural circuit graph mapping inputs to outputs *)
  let module Circuit = Circuit.With_interface (I) (O) in
  let circuit = Circuit.create_exn ~name:"arbitrage_size_filter" create_circuit in
  
  (* 2. Tell the OCaml compiler to translate the graph into pure synthesizable Verilog code *)
  Rtl.print Verilog circuit


