# Steam
Table to with Steam API functions

Steam.SetPersonaName(name: string)
  Sets the player name, stores it on the server and publishes the changes to all friends who are online.
  name: The name to set
Steam.GetPersonaName() -> string
  Returns the local players name. This is the same name as on the users community profile page.
Steam.GetGameLanguage() -> string
  Returns the current game language.
Steam.GetProfilePictureBySteamId(steamID64: integer, [large: boolean = false]) -> integer
  ! This function works only if you already got player's user information (EMsg_ClientRequestFriendData). That means you should be in the same game with the player or he should be in your friend list.
  Returns the handle of the profile picture of the given Steam ID.
  steamID64: The Steam ID of the player
  large: Whether to get the large profile picture
Steam.GetProfilePictureByAccountId(steamID64: integer, [large: boolean = false]) -> integer
  ! This function works only if you already got player's user information (EMsg_ClientRequestFriendData). That means you should be in the same game with the player or he should be in your friend list.
  Returns the handle of the profile picture of the given account id.
  steamID64: The account id of the player
  large: Whether to get the large profile picture
