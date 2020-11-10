module May.Flags exposing (Flags, decode)

{-| The flags are what get passed to the program when starting up. This also
includes local storage information.

    It's handled seperately to allow for more complicated behaviour in regards
    to migrations

-}

import Json.Decode as D
import May.Auth as Auth
import May.FileSystem as FileSystem exposing (FileSystem)


type alias Flags =
    { authCode : Maybe String
    , authTokens : Maybe Auth.AuthTokens
    , fs : Maybe FileSystem
    , offset : String
    }


decode : D.Decoder Flags
decode =
    D.maybe (D.field "version" D.string)
        |> D.andThen
            (\version ->
                case version of
                    Just "1" ->
                        decodeV1

                    _ ->
                        -- Nothing is assumed to be version 1
                        decodeV1
            )


decodeV1 : D.Decoder Flags
decodeV1 =
    D.map4 Flags
        (D.maybe (D.field "code" D.string))
        (D.maybe (D.field "tokens" Auth.tokensDecoder))
        (D.maybe (D.field "fs" FileSystem.decode))
        (D.field "offset" D.string)
