module CustomScalarCodecs exposing (Id, PosixTime, codecs)

import Api.Scalar
import Iso8601
import Json.Decode as Decode
import Json.Encode as Encode
import May.Id
import Time


type alias Id =
    May.Id.Id ()


type alias PosixTime =
    Time.Posix


codecs : Api.Scalar.Codecs Id PosixTime
codecs =
    Api.Scalar.defineCodecs
        { codecId =
            { encoder = May.Id.encode
            , decoder = May.Id.decode
            }
        , codecPosixTime =
            { encoder = Iso8601.encode
            , decoder = Iso8601.decoder
            }
        }
