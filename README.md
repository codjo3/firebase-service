# Firebase Realtime Database for Roblox
<p align="center"><img src="thumbnail.png" height="200"></p>
A Roblox Lua module that enables server-side communication with Firebase Realtime Database through Google Apps Script authentication. Features full CRUD operations, query parameters, and automatic token refresh.

## Installation

### Via Wally
Add to your `wally.toml`:
```toml
[dependencies]
FirebaseService = "codjo3/firebase-service@0.2.0"
```
Then run:
```bash
wally install
```

### Via Roblox Asset Library
Get the module from the [Roblox Creator Store](https://create.roblox.com/store/asset/110275857690667)

### Manual Installation

1. Download `FirebaseService.lua` from this repository
2. Place it in `ServerScriptService`

## Quick Start

```lua
local FirebaseService = require(path.to.FirebaseService)

local myDatabase = FirebaseService.retrieve("your-database-name")
    :Authenticate("https://script.google.com/macros/s/YOUR_SCRIPT_ID/exec", "YOUR_SECRET_KEY")

-- Read data
local success, userData = pcall(function()
    return myDatabase:GetAsync("/users/player123")
end)

if success then
    print("User data:", userData)
end

-- Write data
myDatabase:PutAsync("/users/player123", {
    name = "PlayerName",
    score = 1000,
    lastLogin = os.time()
})
```

## Setup Instructions

### Step 1: Create Firebase Realtime Database
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Navigate to "Realtime Database" and create a database

### Step 2: Configure Google Apps Script
1. Go to [script.google.com](https://script.google.com) and create a new project
2. Click on **Project Settings** (gear icon) and check "Show appsscript.json manifest"
3. Edit `appsscript.json` to include OAuth scopes:
```json
{
  "timeZone": "America/New_York",
  "dependencies": {},
  "oauthScopes": [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/firebase.database",
    "https://www.googleapis.com/auth/script.external_request"
  ],
  "exceptionLogging": "STACKDRIVER"
}
```
4. Replace `Code.gs` content with:
```javascript
function doGet(e) {
  var requestToken = e.parameter.secretKey;
  var expectedSecret = "YOUR_SUPER_SECRET_KEY"; // Change this to a secure key!

  if (requestToken !== expectedSecret) {
    return ContentService.createTextOutput(JSON.stringify({
      success: false,
      result: "Unauthorized"
    })).setMimeType(ContentService.MimeType.JSON);
  }

  try {
    var accessToken = ScriptApp.getOAuthToken();
    return ContentService.createTextOutput(
      JSON.stringify({
        success: true,
        result: accessToken
      })
    ).setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    Logger.log("Error getting access token: " + error.toString());
    return ContentService.createTextOutput(
      JSON.stringify({
        success: false,
        result: "Could not generate token: " + error.message
      })
    ).setMimeType(ContentService.MimeType.JSON);
  }
}
```
5. **Deploy the script:**
   - Click **Deploy** → **New deployment**
   - Select type: **Web app**
   - Execute as: **Me** (your account with Firebase permissions)
   - Who has access: **Anyone**
   - Click **Deploy**
   - Authorize the app (click "Advanced" → "Go to [project] (unsafe)" if needed)
   - Copy the web app URL

### Step 3: Configure Firebase Security Rules
In Firebase Console → Realtime Database → Rules:
```json
{
  "rules": {
    "publicDataForAuthenticatedUsers": {
      ".read": "auth !== null",
      ".write": "auth !== null"
    }
  }
}
```

## API Reference

### Creating a Firebase Instance
```lua
local database = FirebaseService.retrieve(databaseName):Authenticate(scriptUrl, secretKey)
```

- `databaseName`: Your Firebase database name (e.g., "my-game-db")
- `scriptUrl`: Google Apps Script web app URL
- `secretKey`: The secret key you set in your Apps Script

### Reading Data

#### GetAsync
```lua
local data = database:GetAsync(directory, query?)
```

Returns the data at the specified directory, or `nil` if it doesn't exist.
**Example:**
```lua
local success, result = pcall(function()
    return database:GetAsync("/users/player123")
end)
```

### Writing Data

#### PutAsync
Completely overwrites data at the specified directory.
```lua
database:PutAsync(directory, data, query?)
```

**Example:**
```lua
database:PutAsync("/users/player123", {
    name = "John",
    score = 500
})
```

**With function:**
```lua
database:PutAsync("/users/player123", function(currentData)
    return {
        name = currentData.name,
        score = (currentData.score or 0) + 100
    }
end)
```

#### PatchAsync
Merges data with existing data (data must be a table).
```lua
database:PatchAsync(directory, data, query?)
```

**Example:**
```lua
database:PatchAsync("/users/player123", {
    lastLogin = os.time()
})
```

#### PostAsync
Appends data to the directory and returns the generated key.
```lua
local result = database:PostAsync(directory, data, query?)
```

**Example:**
```lua
local result = database:PostAsync("/logs", {
    message = "User logged in",
    timestamp = os.time()
})
print("Created log with key:", result.name)
```

### Deleting Data

#### DeleteAsync
```lua
database:DeleteAsync(directory, condition?, query?)
```

**Unconditional delete:**
```lua
database:DeleteAsync("/users/player123")
```

**Conditional delete:**
```lua
database:DeleteAsync("/users/player123", function(userData)
    -- Only delete if inactive for 30 days
    return os.time() - userData.lastLogin > (30 * 24 * 60 * 60)
end)
```

### Query Parameters

All async functions support optional query parameters:
```lua
type GetQuery = {
    shallow: boolean?,           -- Work with large datasets without downloading everything
    timeout: string?,            -- Limit read time (e.g., "3ms", "3s", "3min")
    orderBy: string?,            -- "$key", "$value", "$priority", or nested key path
    startAt: string | number?,   -- Query range start (requires orderBy)
    endAt: string | number?,     -- Query range end (requires orderBy)
    equalTo: string | number?,   -- Exact match (requires orderBy)
    limitToFirst: number?,       -- Limit results from start (requires orderBy)
    limitToLast: number?,        -- Limit results from end (requires orderBy)
}
```

**Example:**
```lua
local topPlayers = database:GetAsync("/users", {
    orderBy = "score",
    limitToLast = 10
})
```

### Utility Methods

#### Disable
Temporarily disables the database (stops all operations).

```lua
database:Disable()
```

#### Destroy
Destroys the database instance and cleans up memory.

```lua
database:Destroy()
```

## Security Best Practices
1. **Never expose your secret key** - Store it securely, never commit to version control
2. **Use environment-specific keys** - Different keys for testing and production
3. **Configure Firebase Rules** - Implement proper read/write permissions
4. **Validate data** - Always validate data before writing to Firebase
5. **Use pcall** - Wrap all async operations in `pcall` for error handling

## Usage Examples

### Player Data Management
```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    local userId = tostring(player.UserId)
    
    -- Load player data
    local success, data = pcall(function()
        return database:GetAsync("/players/" .. userId)
    end)
    
    if success and data then
        print("Loaded data for", player.Name)
    else
        -- Create new player profile
        database:PutAsync("/players/" .. userId, {
            name = player.Name,
            joinDate = os.time(),
            score = 0
        })
    end
end)

Players.PlayerRemoving:Connect(function(player)
    local userId = tostring(player.UserId)
    
    -- Save player data
    database:PatchAsync("/players/" .. userId, {
        lastSeen = os.time()
    })
end)
```

### Leaderboard System
```lua
local function updateLeaderboard(userId, score)
    database:PatchAsync("/leaderboard/" .. userId, {
        score = score,
        timestamp = os.time()
    })
end

local function getTopPlayers(limit)
    return database:GetAsync("/leaderboard", {
        orderBy = "score",
        limitToLast = limit
    })
end
```

### Event Logging
```lua
local function logEvent(eventType, data)
    database:PostAsync("/events/" .. eventType, {
        data = data,
        timestamp = os.time()
    })
end

logEvent("purchase", {
    userId = player.UserId,
    itemId = "sword_legendary",
    price = 1000
})
```

## Important Notes
- **Server-side only** - This module only works in server scripts
- **Always use pcall** - All async operations can fail and should be wrapped
- **Token refresh** - Access tokens automatically refresh every hour
- **Rate limits** - Be mindful of Firebase and Google Apps Script rate limits

## Contributing
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Links
- [Wally Package](https://wally.run/package/codjo3/firebaseservice/)
- [Roblox Asset Library](https://create.roblox.com/store/asset/110275857690667)
- [Google Apps Script Documentation](https://developers.google.com/apps-script)
