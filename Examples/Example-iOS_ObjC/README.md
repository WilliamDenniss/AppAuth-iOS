# Example Project

## Configuration

The example doesn't work out of the box, you need to configure it your own
client ID.

### Information You'll Need

* Issuer
* Client ID
* Redirect URI

The instructions on how to get this vary by IdP, but we have a 
[docs](../README.md#certified-openid-providers) for some OpenID Certified
providers.

### Configure the Example

#### In the file `AppAuthExampleViewController.m` 

1. Update `kIssuer` with the IdP's issuer.
2. Update `kClientID` with your new client id.
3. Update `kRedirectURI` redirect URI

#### In the file `Info.plist`

Fully expand "URL types" (a.k.a. `CFBundleURLTypes`) and replace
`com.example.app` with the *scheme* of your redirect URI. 
The scheme is everything before the colon (`:`).  For example, if the redirect
URI is `com.example.app:/oauth2redirect/example-provider`, then the scheme
would be `com.example.app`.

### Running the Example

Now your example should be ready to run.

