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
    , hasSubscription
    , name
    , refreshTokens
    , stateAuthTokens
    , tokensDecoder
    , withGqlAuthHeader
    )

{-| Authentication module, handles authenticating and getting tokens and such
things
-}

import Api.Mutation
import Api.Object.OkResult
import Graphql.Http
import Graphql.Operation as Graphql
import Graphql.SelectionSet as Graphql
import Http
import Json.Decode as D
import Json.Encode as E
import Jwt
import May.Urls as Urls
import Task exposing (Task)
import Time


type AuthState
    = Unauthenticated
    | Authenticating
    | AuthFailed
    | Authenticated AuthTokens
    | CheckingSubscription AuthTokens
    | CheckingSubscriptionFailed AuthTokens
    | SubscriptionNeeded AuthTokens
    | SubscriptionRequested AuthTokens
    | SubscriptionRequestFailed AuthTokens
    | DeletingUser AuthTokens
    | DeleteUserFailed AuthTokens


stateAuthTokens : AuthState -> Maybe AuthTokens
stateAuthTokens state =
    case state of
        Authenticated x ->
            Just x

        SubscriptionNeeded x ->
            Just x

        DeletingUser x ->
            Just x

        DeleteUserFailed x ->
            Just x

        CheckingSubscription x ->
            Just x

        CheckingSubscriptionFailed x ->
            Just x

        AuthFailed ->
            Nothing

        Unauthenticated ->
            Nothing

        Authenticating ->
            Nothing

        SubscriptionRequested x ->
            Just x

        SubscriptionRequestFailed x ->
            Just x


authStateToString : AuthState -> String
authStateToString state =
    case state of
        Unauthenticated ->
            "Offline"

        Authenticating ->
            "Authenticating..."

        AuthFailed ->
            "Auth Failed"

        Authenticated _ ->
            "Authenticated"

        SubscriptionNeeded _ ->
            "Get a Subscription"

        SubscriptionRequested _ ->
            "Forwarding you to payment"

        DeletingUser _ ->
            "Deleting User"

        DeleteUserFailed _ ->
            "Deleting User failed"

        CheckingSubscription _ ->
            "Checking for a subscription"

        CheckingSubscriptionFailed _ ->
            "Failed to check for subscription"

        SubscriptionRequestFailed _ ->
            "Failed subscription request"


type AuthTokens
    = AuthTokens AuthTokensInternal


type alias AuthTokensInternal =
    { idToken : String
    , idTokenPayload : IdToken
    , accessToken : String
    , accessTokenPayload : AccessToken
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


type alias AccessToken =
    { groups : List String
    , sub : String
    }


decodeAccessToken : D.Decoder AccessToken
decodeAccessToken =
    D.maybe (D.field "cognito:groups" (D.list D.string))
        |> D.andThen
            (\groupsM ->
                let
                    groups =
                        case groupsM of
                            Just g ->
                                g

                            Nothing ->
                                []
                in
                D.map (AccessToken groups)
                    (D.field "sub" D.string)
            )


tokensDecoder : D.Decoder AuthTokens
tokensDecoder =
    D.map AuthTokens <|
        D.map6 AuthTokensInternal
            (D.field "id_token" D.string)
            (D.field "id_token" (Jwt.tokenDecoder decodeIdToken))
            (D.field "access_token" D.string)
            (D.field "access_token" (Jwt.tokenDecoder decodeAccessToken))
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


withGqlAuthHeader : AuthTokens -> Graphql.Http.Request a -> Graphql.Http.Request a
withGqlAuthHeader (AuthTokens { accessToken }) =
    Graphql.Http.withHeader "Authorization" accessToken


type alias AuthTokensResponse =
    { idToken : String
    , idTokenPayload : IdToken
    , accessToken : String
    , accessTokenPayload : AccessToken
    , refreshToken : String
    , expiresIn : Int
    }


authTokenResponseDecoder : D.Decoder AuthTokensResponse
authTokenResponseDecoder =
    D.map6 AuthTokensResponse
        (D.field "id_token" D.string)
        (D.field "id_token" (Jwt.tokenDecoder decodeIdToken))
        (D.field "access_token" D.string)
        (D.field "access_token" (Jwt.tokenDecoder decodeAccessToken))
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
        , accessTokenPayload = response.accessTokenPayload
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
    Urls.authBase


clientId : String
clientId =
    "1qu0jlg90401pc5lf41jukbd15"


refreshTokenBody : AuthTokens -> String
refreshTokenBody (AuthTokens { refreshToken }) =
    "grant_type=refresh_token&client_id=" ++ clientId ++ "&redirect_uri=https://may.hazelfire.net/&refresh_token=" ++ refreshToken


refreshTokens : (Result String AuthTokens -> a) -> AuthTokens -> Cmd a
refreshTokens message tokens =
    Task.attempt message <|
        (getRefreshTokenTask tokens
            |> Task.andThen authResponseToAuthTokensTask
        )


{-| The refresh token task doesn't actually have a refresh token in the response
so I need to handle it a bit differently
-}
getRefreshTokenTask : AuthTokens -> Task String AuthTokensResponse
getRefreshTokenTask tokens =
    Http.task
        { url = authBase ++ "/oauth2/token"
        , method = "POST"
        , body = Http.stringBody "application/x-www-form-urlencoded" (refreshTokenBody tokens)
        , headers = []
        , timeout = Nothing
        , resolver =
            Http.stringResolver
                (\response ->
                    case response of
                        Http.GoodStatus_ _ string ->
                            case D.decodeString (refreshTokenDecoder tokens) string of
                                Err error ->
                                    Result.Err <| D.errorToString error

                                Ok result ->
                                    Ok result

                        _ ->
                            Result.Err "Could not access web"
                )
        }


refreshTokenDecoder : AuthTokens -> D.Decoder AuthTokensResponse
refreshTokenDecoder (AuthTokens { refreshToken }) =
    D.map6 AuthTokensResponse
        (D.field "id_token" D.string)
        (D.field "id_token" (Jwt.tokenDecoder decodeIdToken))
        (D.field "access_token" D.string)
        (D.field "access_token" (Jwt.tokenDecoder decodeAccessToken))
        (D.succeed refreshToken)
        (D.field "expires_in" D.int)


authTokenNeedsRefresh : Time.Posix -> AuthTokens -> Bool
authTokenNeedsRefresh now (AuthTokens tokens) =
    Time.posixToMillis tokens.expiresAt - Time.posixToMillis now < 5 * 1000 * 60


deleteUser : (Result (Graphql.Http.Error Bool) Bool -> a) -> AuthTokens -> Cmd a
deleteUser message tokens =
    deleteUserSelectionSet
        |> Graphql.Http.mutationRequest (Urls.backendBase ++ "/")
        |> withGqlAuthHeader tokens
        |> Graphql.Http.send message


deleteUserSelectionSet : Graphql.SelectionSet Bool Graphql.RootMutation
deleteUserSelectionSet =
    Api.Mutation.deleteUser Api.Object.OkResult.ok


email : AuthTokens -> String
email (AuthTokens { idTokenPayload }) =
    idTokenPayload.email


name : AuthTokens -> String
name (AuthTokens { idTokenPayload }) =
    idTokenPayload.name


hasSubscription : AuthTokens -> Bool
hasSubscription (AuthTokens { accessTokenPayload }) =
    List.member "Subscribers" accessTokenPayload.groups
