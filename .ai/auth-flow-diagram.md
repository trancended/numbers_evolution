# Przepływ Uwierzytelniania

```mermaid
stateDiagram-v2
    [*] --> Unauthenticated
    Unauthenticated --> Registering : register_user()
    Registering --> Authenticated : success
    Registering --> Unauthenticated : failure

    Unauthenticated --> LoggingIn : login()
    LoggingIn --> Authenticated : success
    LoggingIn --> Unauthenticated : failure

    Authenticated --> [*] : logout()

    Authenticated --> API_Call : with_token
    API_Call --> Authorized : valid_token
    API_Call --> Unauthorized : invalid_token

    Authorized --> Data_Access : user_id scope
    Unauthorized --> Error_Response

    state Authenticated as Authenticated
    state Authorized as Authorized

    note right of Authenticated
        User has valid session
        Can access protected routes
        All queries scoped by user_id
    end note

    note right of Authorized
        API request authenticated
        Rate limits applied
        Data isolation enforced
    end note
```
