open Core

type opportunity = {
  buy_venue  : string;
  sell_venue : string;
  buy_price  : float; 
  sell_price : float; 
  gross_pnl  : float;
}

(* Computes the volume-weighted average price (VWAP) for a given target order size *)
let compute_vwap_price (levels : Order_book_lib.Order_book.level array) (active_count : int) (target_size : float) : float option =
  let remaining_size = ref target_size in
  let accumulated_cost = ref 0.0 in
  let idx = ref 0 in
  
  while !idx < active_count && Float.(!remaining_size > 0.0) do
    let level_size = levels.(!idx).size in
    let level_price = levels.(!idx).price in
    (* FIXED: Changed integer 'min' to 'Float.min' *)
    let take_size = Float.min !remaining_size level_size in
    
    accumulated_cost := !accumulated_cost +. (take_size *. level_price);
    remaining_size := !remaining_size -. take_size;
    idx := !idx + 1
  done;
  
  if Float.equal !remaining_size 0.0 then
    Some (!accumulated_cost /. target_size)
  else
    None

(* Evaluates arbitrage options across the entire depth ladder for a specific size *)
let check_arbitrage_with_depth (book_a : Order_book_lib.Order_book.t) (book_b : Order_book_lib.Order_book.t) ~(target_size : float) : opportunity option =
  let vwap_buy_a = compute_vwap_price book_a.asks book_a.active_asks target_size in
  let vwap_sell_a = compute_vwap_price book_a.bids book_a.active_bids target_size in
  let vwap_buy_b = compute_vwap_price book_b.asks book_b.active_asks target_size in
  let vwap_sell_b = compute_vwap_price book_b.bids book_b.active_bids target_size in
  
  match vwap_buy_a, vwap_sell_a, vwap_buy_b, vwap_sell_b with
  | Some buy_a, Some sell_a, Some buy_b, Some sell_b ->
      if Float.(sell_a > buy_b) then
        Some {
          buy_venue  = "VenueB";
          sell_venue = "VenueA";
          buy_price  = buy_b;
          sell_price = sell_a;
          gross_pnl  = (sell_a -. buy_b) *. target_size;
        }
      else if Float.(sell_b > buy_a) then
        Some {
          buy_venue  = "VenueA";
          sell_venue = "VenueB";
          buy_price  = buy_a;
          sell_price = sell_b;
          gross_pnl  = (sell_b -. buy_a) *. target_size;
        }
      else
        None
  | _, _, _, _ -> None

