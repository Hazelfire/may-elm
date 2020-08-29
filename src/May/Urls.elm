module May.Urls exposing (authBase, backendBase, loginUrl)


type alias Urls =
    { loginUrl : String
    , authBase : String
    , backendBase : String
    }


prodUrls : Urls
prodUrls =
    { loginUrl = "https://auth.may.hazelfire.net/oauth2/authorize?client_id=1qu0jlg90401pc5lf41jukbd15&redirect_uri=https://may.hazelfire.net/&response_type=code"
    , authBase = "https://auth.may.hazelfire.net"
    , backendBase = "https://api.may.hazelfire.net"
    }


devUrls : Urls
devUrls =
    { loginUrl = "https://auth.may.hazelfire.net/oauth2/authorize?client_id=1qu0jlg90401pc5lf41jukbd15&redirect_uri=http://localhost:4002/&response_type=code"
    , authBase = "https://auth.may.hazelfire.net"
    , backendBase = "http://localhost:3000"
    }


usingUrls : Urls
usingUrls =
    prodUrls


authBase : String
authBase =
    usingUrls.authBase


backendBase : String
backendBase =
    usingUrls.backendBase


loginUrl : String
loginUrl =
    usingUrls.loginUrl
