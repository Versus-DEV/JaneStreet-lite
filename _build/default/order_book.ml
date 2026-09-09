open Core

(* We maintain up to 10 tiers of market depth liquidity *)
let max_book_depth = 10

type level = {
  mutable price : float;
  mutable size  : float;
}

type t = {
  symbol : string;
  bids   : level array;
  asks   : level array;
  mutable active_bids : int;
  mutable active_asks : int;
}

let create (sym : string) : t =
  let make_empty_levels () = 
    Array.init max_book_depth ~f:(fun _ -> { price = 0.0; size = 0.0 }) 
  in
  {
    symbol = sym;
    bids   = make_empty_levels ();
    asks   = make_empty_levels ();
    active_bids = 0;
    active_asks = 0;
  }

(* Shift items in an array down to make room for an insertion *)
let shift_down (arr : level array) (start_idx : int) (end_idx : int) : unit =
  for i = end_idx downto start_idx + 1 do
    arr.(i).price <- arr.(i - 1).price;
    arr.(i).size  <- arr.(i - 1).size;
  done

(* High-performance in-place Level 2 insertion engine *)
let insert_level (levels : level array) (active_count : int ref) (price : float) (size : float) ~(is_bid : bool) : unit =
  let found_idx = ref (-1) in
  (* 1. Scan to see if the price level already exists *)
  for i = 0 to !active_count - 1 do
    if Float.equal levels.(i).price price then found_idx := i
  done;

  if !found_idx >= 0 then begin
    (* Level exists: update size or remove if empty *)
    if Float.equal size 0.0 then begin
      (* Shift up to delete the level *)
      for i = !found_idx to !active_count - 2 do
        levels.(i).price <- levels.(i + 1).price;
        levels.(i).size  <- levels.(i + 1).size;
      done;
      active_count := !active_count - 1;
    end else
      levels.(!found_idx).size <- size
  end else if Float.(size > 0.0) then begin
    (* New level: Find sorted insertion point *)
    let insert_idx = ref !active_count in
    let continue = ref true in
    let i = ref 0 in
    
    while !i < !active_count && !continue do
      let price_matches = 
        if is_bid then Float.(price > levels.(!i).price) (* Bids: Highest price first *)
        else Float.(price < levels.(!i).price)           (* Asks: Lowest price first *)
      in
      if price_matches then begin
        insert_idx := !i;
        continue := false;
      end;
      i := !i + 1
    done;

    if !insert_idx < max_book_depth then begin
      let target_end = min max_book_depth (!active_count + 1) - 1 in
      shift_down levels !insert_idx target_end;
      levels.(!insert_idx).price <- price;
      levels.(!insert_idx).size  <- size;
      if !active_count < max_book_depth then active_count := !active_count + 1;
    end
  end

let process_update (book : t) ~(side : [ `Bid | `Ask ]) ~(price : float) ~(size : float) : unit =
  match side with
  | `Bid -> 
      let r = ref book.active_bids in
      insert_level book.bids r price size ~is_bid:true;
      book.active_bids <- !r
  | `Ask -> 
      let r = ref book.active_asks in
      insert_level book.asks r price size ~is_bid:false;
      book.active_asks <- !r

(* Return the top of the Level 2 book (best bid and ask) *)
let get_inside_market (book : t) : (float * float) option =
  if book.active_bids > 0 && book.active_asks > 0 then
    Some (book.bids.(0).price, book.asks.(0).price)
  else
    None

(* Append this function cleanly to the bottom of order_book.ml *)
let print_depth_visualizer (book : t) : unit =
  printf "\n--- 📖 MARKET DEPTH LADDER [%s] 📖 ---\n" book.symbol;
  
  (* 1. Print Ask Levels (Sellers) in descending order (highest price at the top) *)
  printf " [ASKS]\n";
  let max_ask_to_print = min book.active_asks 3 in
  for i = max_ask_to_print - 1 downto 0 do
    printf "   Level %d | Price: %.2f | Volume: %.2f\n" (i + 1) book.asks.(i).price book.asks.(i).size
  done;
  
  printf " -------------------------------------------\n";
  
  (* 2. Print Bid Levels (Buyers) in ascending order (highest price first) *)
  printf " [BIDS]\n";
  let max_bid_to_print = min book.active_bids 3 in
  for i = 0 to max_bid_to_print - 1 do
    printf "   Level %d | Price: %.2f | Volume: %.2f\n" (i + 1) book.bids.(i).price book.bids.(i).size
  done;
  printf "--------------------------------------------\n"

