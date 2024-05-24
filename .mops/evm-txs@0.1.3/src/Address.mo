import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Error "mo:base/Error";
import PublicKey "mo:libsecp256k1/PublicKey";
import Signature "mo:libsecp256k1/Signature";
import Message "mo:libsecp256k1/Message";
import RecoveryId "mo:libsecp256k1/RecoveryId";
import Ecdsa "mo:libsecp256k1/Ecdsa";
import Ecmult "mo:libsecp256k1/core/ecmult";
import Helper "transactions/Helper";
import TU "utils/TextUtils";
import AU "utils/ArrayUtils";
import HU "utils/HashUtils";
import EcdsaApi "interfaces/EcdsaApi";

module {
    public func create(
        keyName: Text,
        derivationPath: [Blob],
        api: EcdsaApi.API
    ): async* Result.Result<(Text, [Nat8]), Text> {
        try {
            let publicKey = Blob.toArray(await* api.create(keyName, derivationPath));
            switch(fromPublicKey(publicKey)) {
                case (#err(msg)) {
                    return #err(msg);
                };
                case (#ok(address)) {
                    return #ok((address, publicKey));
                };
            };
        }
        catch(e: Error.Error) {
            return #err("api.create failed: " # Error.message(e));
        };
    };
   
    public func fromPublicKey(
        publicKey: [Nat8]
    ): Result.Result<Text, Text> {
        if(publicKey.size() != 33) {
            return #err("Invalid length of public key");
        };

        let p = switch(PublicKey.parse_compressed(publicKey)) {
            case (#err(e)) {
                return #err("Invalid public key");
            };
            case (#ok(p)) {
                let keccak256_hex = AU.toText(HU.keccak(AU.right(p.serialize(), 1), 256));
                let address: Text = "0x" # TU.right(keccak256_hex, 24);

                return #ok(address);
            };
        };
    };    

    public func recover(
        signature: [Nat8],
        recoveryId: Nat8,
        message: [Nat8],
        context: Ecmult.ECMultContext
    ): Result.Result<Text, Text> {
        if(signature.size() != 64) {
            return #err("Invalid signature");
        };
        if(message.size() != 32) {
            return #err("Invalid message");
        };

        switch(Signature.parse_standard(signature)) {
            case (#ok(signatureParsed)) {
                switch(RecoveryId.parse(recoveryId)) {
                    case (#ok(recoveryIdParsed)) {
                        let messageParsed = Message.parse(message);
                        switch(Ecdsa.recover_with_context(
                            messageParsed, signatureParsed, recoveryIdParsed, context)) {
                            case (#ok(publicKey)) {
                                let address = fromPublicKey(publicKey.serialize_compressed());
                                return address;
                            };
                            case (#err(msg)) {
                                return #err(debug_show msg);
                            };
                        };
                    };
                    case (#err(msg)) {
                        return #err(debug_show msg);
                    };
                };
            };
            case (#err(msg)) {
                return #err(debug_show msg);
            };
        };
    };
}