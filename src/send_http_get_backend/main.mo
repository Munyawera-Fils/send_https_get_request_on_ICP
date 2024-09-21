import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";

// Import the custom types we have in Types.mo
import Types "Types";

// Actor
actor {

  // This method sends a GET request to a URL with a free API we can test.
  // This method returns cryptocurrency data from CoinGecko.
  public query func transform(raw : Types.TransformArgs) : async Types.CanisterHttpResponsePayload {
    let transformed : Types.CanisterHttpResponsePayload = {
        status = raw.response.status;
        body = raw.response.body;
        headers = [
            {
                name = "Content-Security-Policy";
                value = "default-src 'self'";
            },
            { name = "Referrer-Policy"; value = "strict-origin" },
            { name = "Permissions-Policy"; value = "geolocation=(self)" },
            {
                name = "Strict-Transport-Security";
                value = "max-age=63072000";
            },
            { name = "X-Frame-Options"; value = "DENY" },
            { name = "X-Content-Type-Options"; value = "nosniff" },
        ];
    };
    transformed;
  };
  
  public func get_icp_usd_exchange() : async Text {

    // 1. DECLARE IC MANAGEMENT CANISTER
    // We need this so we can use it to make the HTTP request
    let ic : Types.IC = actor ("aaaaa-aa");

    // 2. SETUP ARGUMENTS FOR HTTP GET request

    // 2.1 Setup the URL and its query parameters
    let ONE_MINUTE : Nat64 = 60;
    let now : Nat64 = 1701292800; // Example timestamp (current time in seconds since epoch)
    let thirty_days_ago : Nat64 = now - (30 * 24 * 60 * 60); // 30 days ago timestamp
    let host : Text = "api.coingecko.com";
    let url = "https://" # host # "/api/v3/coins/bitcoin/market_chart/range?vs_currency=usd&from=" # Nat64.toText(thirty_days_ago) # "&to=" # Nat64.toText(now);

    // 2.2 Prepare headers for the system http_request call
    let request_headers = [
        { name = "Host"; value = host # ":443" },
        { name = "User-Agent"; value = "exchange_rate_canister" },
    ];

    // 2.2.1 Transform context
    let transform_context : Types.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    // 2.3 The HTTP request
    let http_request : Types.HttpRequestArgs = {
        url = url;
        max_response_bytes = null; // Optional for request
        headers = request_headers;
        body = null; // Optional for request
        method = #get;
        transform = ?transform_context;
    };

    // 3. ADD CYCLES TO PAY FOR HTTP REQUEST

    // The IC specification says, "Cycles to pay for the call must be explicitly transferred with the call"
    // IC management canister will make the HTTP request so it needs cycles
    Cycles.add(230_949_972_000);
    
    // 4. MAKE HTTPS REQUEST AND WAIT FOR RESPONSE
    let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);
    
    // 5. DECODE THE RESPONSE

    // Decode the [Nat8] array that is the body into readable text
    let response_body: Blob = Blob.fromArray(http_response.body);
    let decoded_text: Text = switch (Text.decodeUtf8(response_body)) {
        case (null) { "No value returned" };
        case (?y) { y };
    };

    // 6. RETURN RESPONSE OF THE BODY
    decoded_text
  };

};
