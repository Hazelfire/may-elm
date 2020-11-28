module May.Urls exposing (authBase, backendBase, clientId, loginUrl, redirectUri)


type alias Urls =
    { loginUrl : String
    , authBase : String
    , backendBase : String
    , clientId : String
    , redirectUri : String
    }


prodUrls : Urls
prodUrls =
    { loginUrl = "https://auth.may.hazelfire.net/oauth2/authorize?client_id=1qu0jlg90401pc5lf41jukbd15&redirect_uri=https://may.hazelfire.net/&response_type=code"
    , authBase = "https://auth.may.hazelfire.net"
    , backendBase = "https://api.may.hazelfire.net"
    , clientId = "1qu0jlg90401pc5lf41jukbd15"
    , redirectUri = "https://may.hazelfire.net/"
    }


stageUrls : Urls
stageUrls =
    { loginUrl = "https://auth.stage.may.hazelfire.net/oauth2/authorize?client_id=3j0jpjo9956rgn3uv7rttqqpaf&redirect_uri=https://stage.may.hazelfire.net/&response_type=code"
    , authBase = "https://auth.stage.may.hazelfire.net"
    , backendBase = "https://api.stage.may.hazelfire.net"
    , clientId = "3j0jpjo9956rgn3uv7rttqqpaf"
    , redirectUri = "https://stage.may.hazelfire.net/"
    }


devUrls : Urls
devUrls =
    { loginUrl = "https://auth.may.hazelfire.net/oauth2/authorize?client_id=1qu0jlg90401pc5lf41jukbd15&redirect_uri=http://localhost:4002/&response_type=code"
    , authBase = "https://auth.may.hazelfire.net"
    , backendBase = "http://localhost:3000"
    , clientId = ""
    , redirectUri = "http://localhost:4002/"
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


clientId : String
clientId =
    usingUrls.clientId


redirectUri : String
redirectUri =
    usingUrls.redirectUri
