-- Do not manually edit this file, it was auto-generated by dillonkearns/elm-graphql
-- https://github.com/dillonkearns/elm-graphql


module Api.Scalar exposing (Codecs, Id(..), PosixTime(..), defaultCodecs, defineCodecs, unwrapCodecs, unwrapEncoder)

import Graphql.Codec exposing (Codec)
import Graphql.Internal.Builder.Object as Object
import Graphql.Internal.Encode
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


type Id
    = Id String


type PosixTime
    = PosixTime String


defineCodecs :
    { codecId : Codec valueId
    , codecPosixTime : Codec valuePosixTime
    }
    -> Codecs valueId valuePosixTime
defineCodecs definitions =
    Codecs definitions


unwrapCodecs :
    Codecs valueId valuePosixTime
    ->
        { codecId : Codec valueId
        , codecPosixTime : Codec valuePosixTime
        }
unwrapCodecs (Codecs unwrappedCodecs) =
    unwrappedCodecs


unwrapEncoder getter (Codecs unwrappedCodecs) =
    (unwrappedCodecs |> getter |> .encoder) >> Graphql.Internal.Encode.fromJson


type Codecs valueId valuePosixTime
    = Codecs (RawCodecs valueId valuePosixTime)


type alias RawCodecs valueId valuePosixTime =
    { codecId : Codec valueId
    , codecPosixTime : Codec valuePosixTime
    }


defaultCodecs : RawCodecs Id PosixTime
defaultCodecs =
    { codecId =
        { encoder = \(Id raw) -> Encode.string raw
        , decoder = Object.scalarDecoder |> Decode.map Id
        }
    , codecPosixTime =
        { encoder = \(PosixTime raw) -> Encode.string raw
        , decoder = Object.scalarDecoder |> Decode.map PosixTime
        }
    }
