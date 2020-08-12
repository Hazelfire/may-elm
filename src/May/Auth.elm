module May.Auth exposing
    ( AuthState(..)
    , AuthTokens
    , authHeader
    , authStateToString
    , authTokenNeedsRefresh
    , deleteUser
    , email
    , encodeTokens
    , exchangeAuthCode
    , name
    , refreshTokens
    , stateAuthTokens
    , tokensDecoder
    )

{-| Authentication module, handles authenticating and getting tokens and such
things
-}

import Http
import Json.Decode as D
import Json.Encode as E
import Jwt
import Task exposing (Task)
import Time


type AuthState
    = Unauthenticated
    | Authenticating
    | CheckingSubscription AuthTokens
    | AuthFailed
    | Authenticated AuthTokens
    | SubscriptionNeeded AuthTokens
    | SubscriptionRequested
    | DeletingUser AuthTokens
    | DeleteUserFailed AuthTokens


stateAuthTokens : AuthState -> Maybe AuthTokens
stateAuthTokens state =
    case state of
        CheckingSubscription x ->
            Just x

        Authenticated x ->
            Just x

        SubscriptionNeeded x ->
            Just x

        DeletingUser x ->
            Just x

        DeleteUserFailed x ->
            Just x

        _ ->
            Nothing


authStateToString : AuthState -> String
authStateToString state =
    case state of
        Unauthenticated ->
            "Offline"

        Authenticating ->
            "Authenticating..."

        CheckingSubscription _ ->
            "Checking Subscription"

        AuthFailed ->
            "Auth Failed"

        Authenticated _ ->
            "Authenticated"

        SubscriptionNeeded _ ->
            "Get a Subscription"

        SubscriptionRequested ->
            "Forwarding you to payment"

        DeletingUser _ ->
            "Deleting User"

        DeleteUserFailed _ ->
            "Deleting User failed"


type AuthTokens
    = AuthTokens AuthTokensInternal


type alias AuthTokensInternal =
    { idToken : String
    , idTokenPayload : IdToken
    , accessToken : String
    , refreshToken : String
    , expiresAt : Time.Posix
    }


type alias IdToken =
    { sub : String
    , email : String
    , name : String
    }


decodeIdToken : D.Decoder IdToken
decodeIdToken =
    D.map3 IdToken
        (D.field "sub" D.string)
        (D.field "email" D.string)
        (D.field "name" D.string)


tokensDecoder : D.Decoder AuthTokens
tokensDecoder =
    D.map AuthTokens <|
        D.map5 AuthTokensInternal
            (D.field "id_token" D.string)
            (D.field "id_token" (Jwt.tokenDecoder decodeIdToken))
            (D.field "access_token" D.string)
            (D.field "refresh_token" D.string)
            (D.field "expires_at" (D.map Time.millisToPosix D.int))


encodeTokens : AuthTokens -> E.Value
encodeTokens (AuthTokens tokens) =
    E.object
        [ ( "id_token", E.string tokens.idToken )
        , ( "access_token", E.string tokens.accessToken )
        , ( "refresh_token", E.string tokens.refreshToken )
        , ( "expires_at", E.int (Time.posixToMillis tokens.expiresAt) )
        ]


authHeader : AuthTokens -> Http.Header
authHeader (AuthTokens authTokens) =
    Http.header "Authorization" authTokens.accessToken


type alias AuthTokensResponse =
    { idToken : String
    , idTokenPayload : IdToken
    , accessToken : String
    , refreshToken : String
    , expiresIn : Int
    }


authTokenResponseDecoder : D.Decoder AuthTokensResponse
authTokenResponseDecoder =
    D.map5 AuthTokensResponse
        (D.field "id_token" D.string)
        (D.field "id_token" (Jwt.tokenDecoder decodeIdToken))
        (D.field "access_token" D.string)
        (D.field "refresh_token" D.string)
        (D.field "expires_in" D.int)


exchangeAuthCode : (Result String AuthTokens -> a) -> String -> Cmd a
exchangeAuthCode message authCode =
    Task.attempt message <|
        (getTokenTask (exchangeAuthCodeBody authCode)
            |> Task.andThen authResponseToAuthTokensTask
        )


authResponseToAuthTokensTask : AuthTokensResponse -> Task String AuthTokens
authResponseToAuthTokensTask tokens =
    Time.now
        |> Task.andThen
            (\now ->
                Task.succeed (authResponseToAuthTokens now tokens)
            )


authResponseToAuthTokens : Time.Posix -> AuthTokensResponse -> AuthTokens
authResponseToAuthTokens time response =
    let
        expiresAt =
            Time.millisToPosix (Time.posixToMillis time + (response.expiresIn * 1000))
    in
    AuthTokens
        { expiresAt = expiresAt
        , idToken = response.idToken
        , idTokenPayload = response.idTokenPayload
        , accessToken = response.accessToken
        , refreshToken = response.refreshToken
        }


getTokenTask : String -> Task String AuthTokensResponse
getTokenTask body =
    Http.task
        { url = authBase ++ "/oauth2/token"
        , method = "POST"
        , body = Http.stringBody "application/x-www-form-urlencoded" body
        , headers = []
        , timeout = Nothing
        , resolver =
            Http.stringResolver
                (\response ->
                    case response of
                        Http.GoodStatus_ _ string ->
                            case D.decodeString authTokenResponseDecoder string of
                                Err error ->
                                    Result.Err <| D.errorToString error

                                Ok result ->
                                    Ok result

                        _ ->
                            Result.Err "Could not access web"
                )
        }


exchangeAuthCodeBody : String -> String
exchangeAuthCodeBody code =
    "grant_type=authorization_code&client_id=" ++ clientId ++ "&redirect_uri=https://may.hazelfire.net/&code=" ++ code


authBase : String
authBase =
    "https://auth.may.hazelfire.net"


clientId : String
clientId =
    "1qu0jlg90401pc5lf41jukbd15"


refreshTokenBody : AuthTokens -> String
refreshTokenBody (AuthTokens { refreshToken }) =
    "grant_type=refresh_token&client_id=" ++ clientId ++ "&redirect_uri=https://may.hazelfire.net/&refresh_token=" ++ refreshToken


refreshTokens : (Result String AuthTokens -> a) -> AuthTokens -> Cmd a
refreshTokens message tokens =
    Task.attempt message <|
        (getTokenTask (refreshTokenBody tokens)
            |> Task.andThen authResponseToAuthTokensTask
        )


authTokenNeedsRefresh : Time.Posix -> AuthTokens -> Bool
authTokenNeedsRefresh now (AuthTokens tokens) =
    Time.posixToMillis tokens.expiresAt - Time.posixToMillis now < 5 * 1000 * 60


deleteUser : (Result Http.Error () -> a) -> AuthTokens -> Cmd a
deleteUser message tokens =
    Http.request
        { url = "https://api.may.hazelfire.net/me"
        , method = "DELETE"
        , body = Http.emptyBody
        , headers = [ authHeader tokens ]
        , timeout = Nothing
        , tracker = Nothing
        , expect = Http.expectWhatever message
        }


email : AuthTokens -> String
email (AuthTokens { idTokenPayload }) =
    idTokenPayload.email


name : AuthTokens -> String
name (AuthTokens { idTokenPayload }) =
    idTokenPayload.name
