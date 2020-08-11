module May.Auth exposing
    ( AuthState(..)
    , AuthTokens
    , authHeader
    , authStateToString
    , encodeTokens
    , exchangeAuthCode
    , stateAuthTokens
    , tokensDecoder
    )

{-| Authentication module, handles authenticating and getting tokens and such
things
-}

import Http
import Json.Decode as D
import Json.Encode as E


type AuthState
    = Unauthenticated
    | Authenticating String
    | CheckingSubscription AuthTokens
    | AuthFailed
    | Authenticated AuthTokens
    | SubscriptionNeeded AuthTokens
    | SubscriptionRequested


stateAuthTokens : AuthState -> Maybe AuthTokens
stateAuthTokens state =
    case state of
        CheckingSubscription x ->
            Just x

        Authenticated x ->
            Just x

        SubscriptionNeeded x ->
            Just x

        _ ->
            Nothing


authStateToString : AuthState -> String
authStateToString state =
    case state of
        Unauthenticated ->
            "Offline"

        Authenticating _ ->
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


exchangeAuthCode : (Result Http.Error AuthTokens -> a) -> String -> Cmd a
exchangeAuthCode message authCode =
    Http.request
        { url = authBase ++ "/oauth2/token"
        , method = "POST"
        , body = Http.stringBody "application/x-www-form-urlencoded" (exchangeAuthCodeBody authCode)
        , headers = []
        , timeout = Nothing
        , tracker = Nothing
        , expect = Http.expectJson message tokensDecoder
        }


authBase : String
authBase =
    "https://auth.may.hazelfire.net"


clientId : String
clientId =
    "1qu0jlg90401pc5lf41jukbd15"


exchangeAuthCodeBody : String -> String
exchangeAuthCodeBody code =
    "grant_type=authorization_code&client_id=" ++ clientId ++ "&redirect_uri=https://may.hazelfire.net/&code=" ++ code


type AuthTokens
    = AuthTokens AuthTokensInternal


type alias AuthTokensInternal =
    { idToken : String
    , accessToken : String
    , refreshToken : String
    , expiresIn : Int
    }


tokensDecoder : D.Decoder AuthTokens
tokensDecoder =
    D.map AuthTokens <|
        D.map4 AuthTokensInternal
            (D.field "id_token" D.string)
            (D.field "access_token" D.string)
            (D.field "refresh_token" D.string)
            (D.field "expires_in" D.int)


encodeTokens : AuthTokens -> E.Value
encodeTokens (AuthTokens tokens) =
    E.object
        [ ( "id_token", E.string tokens.idToken )
        , ( "access_token", E.string tokens.accessToken )
        , ( "refresh_token", E.string tokens.refreshToken )
        , ( "expires_in", E.int tokens.expiresIn )
        ]


authHeader : AuthTokens -> Http.Header
authHeader (AuthTokens authTokens) =
    Http.header "Authorization" authTokens.idToken
