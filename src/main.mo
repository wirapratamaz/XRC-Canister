// exchange rate canister (XRC)

import XRC "canister:xrc";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Char "mo:base/Char";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat32";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Trie "mo:base/Trie";
import TrieMap "mo:base/TrieMap";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Prelude "mo:base/Prelude";
import Map "mo:map/Map";
import { thash } "mo:map/Map";
import Sha256 "mo:sha2/Sha256";
import Hex "Hex";

import HttpTypes "http/http";
import SupdTypes "Types";
import Utils "Utils";

import ChainF "helper/ChainFactory";
import TokenF "helper/TokenFactory";
import CurrencyF "currency/FXFactory";
import PriceF "helper/PriceFactory";
import TokenFactory "helper/TokenFactory";

import Canistergeek "mo:canistergeek/canistergeek";

actor {

    private let FX_CACHE_TIME_SECONDS : Nat = 600; //10 min cache

    let IS_TEST_MODE : Bool = true; //enables all test tokens and chains

    stable var _canistergeekMonitorUD : ?Canistergeek.UpgradeData = null;
    private let canistergeekMonitor = Canistergeek.Monitor();
    stable var _canistergeekLoggerUD : ?Canistergeek.LoggerUpgradeData = null;
    private let canistergeekLogger = Canistergeek.Logger();

    system func preupgrade() {
        _canistergeekMonitorUD := ?canistergeekMonitor.preupgrade();
        _canistergeekLoggerUD := ?canistergeekLogger.preupgrade();
    };

    system func postupgrade() {
        canistergeekMonitor.postupgrade(_canistergeekMonitorUD);
        _canistergeekMonitorUD := null;

        canistergeekLogger.postupgrade(_canistergeekLoggerUD);
        _canistergeekLoggerUD := null;
        canistergeekLogger.setMaxMessagesCount(3000);

        canistergeekLogger.logMessage("postupgrade");
    };

    public query (msg) func whoami() : async Principal {
        return msg.caller;
    };

    public query func canisterId() : async Text {
        let p = Principal.fromActor(this);
        return Principal.toText(p);
    };

    //to help https outcall reach consensus you strip the resulting headers
    public query func transform_response(raw : HttpTypes.TransformArgs) : async HttpTypes.HttpResponsePayload {
        let transformed : HttpTypes.HttpResponsePayload = {
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
        return transformed;
    };

    // extract the current change rate from the XRC canister and return it as a float value (e.g. 1.23)
    public func get_exchange_rate(symbol : Text) : async Float {

        let request : XRC.GetExchangeRateRequest = {
            base_asset = {
                symbol = symbol;
                class_ = #Cryptocurrency;
            };
            quote_asset = {
                symbol = "USDT";
                class_ = #Cryptocurrency;
            };
            // Get the current rate.
            timestamp = null;
        };

        // Every XRC call needs 1B cycles.
        Cycles.add<system>(1_000_000_000); // Specify the capability explicitly
        let response = await XRC.get_exchange_rate(request);
        // Print out the response to get a detailed view.
        Dbg.print(debug_show (response));
        // Return 0.0 if there is an error for the sake of simplicity.
        switch (response) {
            case (#Ok(rate_response)) {
                let float_rate = Float.fromInt(Nat64.toNat(rate_response.rate));
                let float_divisor = Float.fromInt(Nat32.toNat(10 ** rate_response.metadata.decimals));
                return float_rate / float_divisor;
            };
            case _ {
                return 0.0;
            };
        };
    };
};
