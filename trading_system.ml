open Core
open Async

let port = 9999

(* Task 1: Simulated Exchange Broadcasting Realistic JSON Frames *)
let run_mock_exchange_server () =
  let handle_client _client_addr reader writer =
    let rec read_orders_loop () =
      Reader.read_line reader >>= function
      | `Eof -> Deferred.unit
      | `Ok order_line ->
          (* Simple acknowledgement for order submission payloads *)
          if String.is_prefix order_line ~prefix:"EXECUTE" then
            printf "[🏛️ MATCHING ENGINE] Trade Intake Payload Acknowledged over Socket\n";
          read_orders_loop ()
    in
    don't_wait_for (read_orders_loop ());

    let rec market_data_loop () =
      if Writer.is_closed writer then
        Deferred.unit
      else begin
        let bid_price = 65000.0 +. (Random.float 20.0) in
        let ask_price = bid_price +. 5.0 in
        (* Format our feed into standard structural JSON strings *)
        let json_msg = sprintf "{\"type\":\"tick\",\"symbol\":\"BTC\",\"bid\":%.2f,\"ask\":%.2f}\n" 
          bid_price ask_price in
        
        Writer.write writer json_msg;
        after (Time_float.Span.of_ms 250.0) >>= market_data_loop
      end
    in
    market_data_loop ()
  in
  let server = Tcp.Where_to_listen.of_port port in
  let server_deferred = Tcp.Server.create ~on_handler_error:`Ignore server handle_client in
  don't_wait_for (Deferred.map server_deferred ~f:(fun _server -> ()))

(* Task 2: Advanced Trading Client parsing JSON frames with type protection *)
let run_trading_client () =
  let book_a = Order_book_lib.Order_book.create "BTC" in
  let book_b = Order_book_lib.Order_book.create "BTC" in
  let risk_controller = Risk_manager.create ~max_trades:5 in
  
  Order_book_lib.Order_book.process_update book_b ~side:`Bid ~price:65014.0 ~size:1.0;
  Order_book_lib.Order_book.process_update book_b ~side:`Ask ~price:65016.0 ~size:1.0;

  printf "System: Establishing stream client link on port %d...\n" port;
  Tcp.connect (Tcp.Where_to_connect.of_host_and_port { host = "127.0.0.1"; port })
  >>= fun (_socket, reader, writer) ->
  printf "System: JSON Deserializer active. Parsing live network frames...\n";
  
  let rec read_loop () =
    Reader.read_line reader >>= function
    | `Eof -> Deferred.unit
    | `Ok line ->
        let start_time = Time_ns.now () in
        begin try
          (* 1. Use Yojson to parse the raw network line block string into a structured AST *)
          let json = Yojson.Safe.from_string line in
          let open Yojson.Safe.Util in
          
          let packet_type = json |> member "type" |> to_string in
          if String.equal packet_type "tick" then begin
            let bid = json |> member "bid" |> to_float in
            let ask = json |> member "ask" |> to_float in
            
            Order_book_lib.Order_book.process_update book_a ~side:`Bid ~price:bid ~size:1.0;
            Order_book_lib.Order_book.process_update book_a ~side:`Ask ~price:ask ~size:1.0;
            
            begin match Arbitrage.check_arbitrage book_a book_b with
            | Some opp ->
                let end_time = Time_ns.now () in
                let internal_latency = Time_ns.diff end_time start_time in
                
                begin match Risk_manager.validate_order risk_controller with
                | `Approve ->
                    printf "\n🚨 NETWORK JSON ARBITRAGE CROSS CAPTURED 🚨\n";
                    printf "Strategy -> Yield target: $%.2f | JSON Deserialization + Logic Latency: %s\n"
                      opp.gross_pnl (Time_ns.Span.to_string_hum internal_latency);
                    
                    let order_payload = sprintf "EXECUTE,BTC,BUY,%.2f,%s\n" 
                      opp.buy_price (Time_ns.to_string_utc end_time) in
                    Writer.write writer order_payload
                | `Reject _reason -> ()
                end
            | None -> ()
            end
          end
        with _ -> () (* Safely skip corrupted packet objects *)
        end;
        read_loop ()
  in
  read_loop ()

let main () =
  printf "=== 🌐 INITIALIZING JANE STREET JSON WORKSPACE PIPELINE 🌐 ===\n";
  Random.self_init ();
  run_mock_exchange_server ();
  after (Time_float.Span.of_ms 100.0) >>= fun () ->
  don't_wait_for (run_trading_client ());
  
  after (Time_float.Span.of_sec 4.0) >>= fun () ->
  printf "\n=== 🛑 LIVE NETWORKING SIMULATION CONCLUDED 🛑 ===\n";
  shutdown 0;
  Deferred.unit

let () =
  don't_wait_for (main ());
  never_returns (Scheduler.go ())

