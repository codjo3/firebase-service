--!strict
--[[

After building a realtime firebase, follow these steps to get started using this module!

1. Make an app script at script.google.com
	- 1. Show the appsscript.json manifest of the script through "Project Settings"
	- 2. Add an "oauthScopes" array with the following values:
			"https://www.googleapis.com/auth/userinfo.email"
			"https://www.googleapis.com/auth/firebase.database"
			"https://www.googleapis.com/auth/script.external_request"
		- (Your appsscript.json should now look something like this below)
			{
			  "timeZone": "Country/State",
			  "dependencies": {},
			  "oauthScopes": [
			  	"https://www.googleapis.com/auth/userinfo.email",
			    "https://www.googleapis.com/auth/firebase.database",
			    "https://www.googleapis.com/auth/script.external_request"
			  ],
			  "exceptionLogging": "STACKDRIVER"
			}
		- Save the file by CTRL + S or find the save file button
	- 3. Set the Code.gs code to this:
			function doGet(e) {
			  var requestToken = e.parameter.secretKey;
			  var expectedSecret = "YOUR_SUPER_SECRET_KEY"; // Change this!

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
		- Save the file by CTRL + S or find the save file button
	- 4. Go to Deploy -> New deployment, select "Web app" as the type
		- Set "Execute as:" to whichever account that has the firebase permissions (most likely "Me")
		- Set "Who has access:" to Anyone
		- Click Deploy. It's okay if it says "Google hasn't verified this app". Click advanced and click "Go to ... (unsafe)".
			- You'll get a URL for your web app. Use it for making new Firebase objects for this module alongside the key
			  by doing local base = FirebaseService.retrieve(DATABASE_NAME):Authenticate(URL, SECRET_KEY).
2. Set the realtime database rules in the Firebase console
	- If you don't know what you're doing, simply set the rules to:
		{
		  "rules": {
		    "publicDataForAuthenticatedUsers": {
		      ".read": "auth !== null",
		      ".write": "auth !== null"
		    }
		  }
		}
3. If you followed the steps correctly, your firebase should work and you will be able to access it in ROBLOX!

---------------------------------------------------------------------------------------------------------------------------------------------

Here is how to use this module!

local FirebaseService = require(path.to.FirebaseService)
local myDatabase: FirebaseService.Firebase = FirebaseService.retrieve("name-from-firebase"):Authenticate(
	"https://script.google.com/macros/s/abcdef", "SECRET_KEY")

-- note when using these functions below, wrap them in a pcall() because they're all prone to error (except retrieve, disable, and destroy)!

--> reading data
-- :GetAsync(directory) will return the data if it exists, or nil if it doesn't.

local success, response = pcall(function() return myDatabase:GetAsync("/users/player123") end)
if success then
	print("player123's data:", response)
else
	print("Error getting player123's data!", response)
end

--> writing data
-- :PutAsync(directory, data/function(currentData)) will write the data to the specified directory (completely overwrites everything).
-- :PatchAsync(directory, data/function(currentData)) will merge the data with the existing data (argument must be or return a table).
-- :PostAsync(directory, data/function(currentData)) will append the data to the specified directory
		-- PostAsync returns a table with the key that it appended with. PutAsync and PatchAsync doesn't return anything.

local success, response = pcall(function()
	return myDatabase:PutAsync("/users/player123", {
		name = "PlayerName",
		score = 1000,
		lastLogin = os.time()
	})
end)

if success then
	print("Successfully made a profile for player123!")
else
	print("Error writing player123's data!", response)
end

-- or with a function..

local success, response = pcall(function()
	return myDatabase:PatchAsync("/users/player123", function(data)
		if data.lastLogin + 30 > os.time() then
			return {} -- don't change data because he hasn't logged in in the last 30 seconds
		end

		return { lastLogin = os.time(), score = (data.score or 0) + 1 }
	end)
end)

if success then
	print("Successfully incremented player123's score and updated his last login!")
else
	print("Error writing player123's data!", response)
end

-- or do a post!

local success, response = pcall(function()
	return myDatabase:PostAsync("/logs", { message = "player123's data was set!" })
end)

if success then
	print("New log was sent to the firebase with key " .. response.name)
else
	print("Error sending log!", response)
end

--> deleting data
-- :DeleteAsync(directory, condition(data)?) removes data from the database, and it has an optional function argument for checking if it should delete

myDatabase:DeleteAsync("/users/player123", function(userData)
	return os.time() - userData.lastLogin > (30 * 24 * 60 * 60) -- Only delete if user hasn't logged in for 30 days
end)

-- or ...

myDatabase:DeleteAsync("/users/player123") -- delete unconditionally

--> others
-- :Disable() when you dont want any data to be read/written (have to call :Authenticate(URL, KEY) again to boot up the base)
-- :Destroy() when you want to release memory

myDatabase:Disable() -- now any calls like GetAsync and PostAsync won't work anymore, they'll just return nothing!

myDatabase:Destroy() -- now the database is useless, and the FirebaseService will no longer have a reference to it
print(myDatabase) -- {}!

-- Finally, all the async functions have a query as an optional argument for specific data requests, and
-- the structure of the dictionary is noted in the "GetQuery" type if you scroll a bit.

]]

if not game:GetService("RunService"):IsServer() then
	error("This module can only be called by the server")
end

export type GetQuery = {
	-- https://firebase.google.com/docs/reference/rest/database#section-query-parameters

	shallow: boolean?, -- lets you work with large datasets without needing to download everything
	timeout: string?, -- limits how long the read takes on the server side via error - following format: 3ms, 3s, or 3min, with a number and a unit
	orderBy: string?, -- $key, $value, $priority, or certain (nested) keys within the JSON (example: "currencies/cash")

	-- these allows us to choose arbitrary starting and ending points for our queries
	startAt: string | number?, -- must be used with orderBy
	endAt: string | number?, -- must be used with orderBy
	equalTo: string | number?, -- must be used with orderBy

	-- these are used to set a maximum number of children for which to receive data
	limitToFirst: number?, -- must be used with orderBy
	limitToLast: number?, -- must be used with orderBy
}

export type Firebase = {
	name: string,
	active: boolean,
	thread: thread?,

	Authenticate: (self: Firebase, url: string, key: string) -> Firebase,
	GetAsync: (self: Firebase, directory: string?, query: GetQuery?) -> any,
	PutAsync: (self: Firebase, directory: string?, data: any, query: GetQuery?) -> (),
	PatchAsync: (self: Firebase, directory: string?, data: any, query: GetQuery?) -> (),
	PostAsync: (self: Firebase, directory: string?, data: any, query: GetQuery?) -> { name: string }?,
	DeleteAsync: (self: Firebase, directory: string?, condition: ((any) -> boolean)?, query: GetQuery?) -> (),
	Disable: (self: Firebase) -> (),
	Destroy: (self: Firebase) -> (),
}

local HttpService = game:GetService("HttpService")
local __privates = {}

local function baseUrl(name: string, directory: string?, query: {}?)
	local newDirectory = ""
	if not directory then
		newDirectory = "/"
	elseif string.sub(directory, 1, 1) == "/" then
		newDirectory = directory
	else
		newDirectory = "/" .. directory
	end

	local queryString = ""
	if query then
		for k, v in query do
			queryString = queryString
				.. HttpService:UrlEncode(tostring(k))
				.. "="
				.. (if type(v) == "string" then ('"' .. v .. '"') else tostring(v))
				.. "&"
		end
	end

	return "https://"
		.. name
		.. "-default-rtdb.firebaseio.com"
		.. newDirectory
		.. ".json?"
		.. queryString
		.. "access_token="
end

local Firebase = { bases = {} }
Firebase.__index = Firebase

function Firebase.retrieve(name: string)
	if Firebase.bases[name] then
		return Firebase.bases[name]
	end

	local self = setmetatable({}, Firebase)
	__privates[self] = {}

	self._active = false
	self.name = name

	Firebase.bases[name] = self
	return self
end

function Firebase:Authenticate(url: string, key: string)
	assert(
		type(url) == "string" and string.match(url, "https?://[%w%d%-%./]+"),
		"url (first argument) must be the url to the app script macro"
	)

	local json = HttpService:GetAsync(url .. "?secretKey=" .. key)
	local response = HttpService:JSONDecode(json)

	if response.success ~= true then
		error("Authorization Error - " .. response.result)
	end

	__privates[self].key = key
	__privates[self].token = response.result

	self._updateKey = function()
		local success, response = pcall(self.Authenticate, self, url, __privates[self].key)
		if not success then
			warn(response)
		end
	end

	if not self.thread then
		self.thread = task.delay(3600, function()
			while self.active do
				self._updateKey()
				task.wait(3600)
			end
		end)
	end

	self.active = true
	return self
end

function Firebase:_post(callback, isRecursive: true?)
	local response = callback()
	if response.StatusCode == 401 then
		if isRecursive then
			error("The request violates your Firebase Realtime Database Security Rules.")
		else
			self._updateKey()
			return self:_post(callback, true)
		end
	elseif not response.Success then
		error(response.StatusCode .. " - " .. response.StatusMessage)
	end

	return response.Body
end

function Firebase:GetAsync(directory: string?, query: GetQuery?)
	assert(not directory or type(directory) == "string", "directory (first argument) must be a string if specified")

	if query then
		assert(type(query) == "table", "query (second argument) must be a dictionary if specified")
		assert(not query.shallow or type(query.shallow) == "boolean", "query.shallow must be a boolean if specified")

		if query.timeout then
			assert(string.match(query.timeout, "^%d+"), "query.timeout has an incorrect format")
		end

		assert(not query.orderBy or type(query.orderBy) == "string", "query.orderBy must be a string if specified")
		assert(
			not query.startAt or (query.startAt and query.orderBy),
			"query.orderBy must exist if query.startAt is specified"
		)
		assert(
			not query.endAt or (query.endAt and query.orderBy),
			"query.orderBy must exist if query.endAt is specified"
		)
		assert(
			not query.equalTo or (query.equalTo and query.orderBy),
			"query.orderBy must exist if query.equalTo is specified"
		)
		assert(
			not query.limitToFirst or (query.limitToFirst and query.orderBy),
			"query.orderBy must exist if query.limitToFirst is specified"
		)
		assert(
			not query.limitToLast or (query.limitToLast and query.orderBy),
			"query.orderBy must exist if query.limitToLast is specified"
		)

		assert(
			not query.limitToFirst or type(query.limitToFirst) == "number",
			"query.limitToFirst must be a number if specified"
		)
		assert(
			not query.limitToLast or type(query.limitToLast) == "number",
			"query.limitToLast must be a number if specified"
		)

		assert(not query["access_token"], "query.access_token is not an allowed key")
		assert(not query["auth"], "query.auth is not an allowed key")
		assert(not query["print"], "query.print is not an allowed key")
		assert(not query["format"], "query.format is not an allowed key")
		assert(not query["download"], "query.download is not an allowed key")
	end

	if not self.active then
		return
	end

	local json = self:_post(function()
		return HttpService:RequestAsync({
			Url = baseUrl(self.name, directory, query) .. __privates[self].token,
			Method = "GET",
		})
	end)

	local body = if json == "" then nil else HttpService:JSONDecode(json)
	return body
end

function Firebase:PutAsync(directory: string?, data, query: GetQuery?)
	assert(not directory or type(directory) == "string", "directory (first argument) must be a string if specified")
	assert(data, "data (second argument) is required to edit the database")

	if not self.active then
		return
	end

	local json
	do
		if type(data) == "function" then
			local body = self:GetAsync(directory, query)
			json = HttpService:JSONEncode(data(body))
		else
			json = HttpService:JSONEncode(data)
		end
	end

	self:_post(function()
		return HttpService:RequestAsync({
			Url = baseUrl(self.name, directory) .. __privates[self].token,
			Method = "PUT",
			Headers = { ["Content-Type"] = "application/json" },
			Body = json,
		})
	end)
end

function Firebase:PatchAsync(directory: string?, data, query: GetQuery?)
	assert(not directory or type(directory) == "string", "directory (first argument) must be a string if specified")

	if not self.active then
		return
	end

	local json
	do
		if type(data) == "function" then
			local body = self:GetAsync(directory, query)
			local toEncode = data(body)
			assert(type(toEncode) == "table", "data (second argument) is required to return a table")
			json = HttpService:JSONEncode(toEncode)
		else
			assert(
				data and type(data) == "table",
				"data (second argument) is a required to edit the database and must be a table"
			)
			json = HttpService:JSONEncode(data)
		end
	end

	self:_post(function()
		return HttpService:RequestAsync({
			Url = baseUrl(self.name, directory) .. __privates[self].token,
			Method = "PATCH",
			Headers = { ["Content-Type"] = "application/json" },
			Body = json,
		})
	end)
end

function Firebase:PostAsync(directory: string?, data, query: GetQuery?)
	assert(not directory or type(directory) == "string", "directory (first argument) must be a string if specified")
	assert(data, "data must be passed to edit the database")

	if not self.active then
		return
	end

	local json
	do
		if type(data) == "function" then
			local body = self:GetAsync(directory, query)
			json = HttpService:JSONEncode(data(body))
		else
			json = HttpService:JSONEncode(data)
		end
	end

	local keyJson = self:_post(function()
		return HttpService:RequestAsync({
			Url = baseUrl(self.name, directory) .. __privates[self].token,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = json,
		})
	end)

	local body = if keyJson == "" then nil else HttpService:JSONDecode(keyJson)
	return body
end

function Firebase:DeleteAsync(directory: string?, condition: (any) -> boolean, query: GetQuery?)
	assert(not directory or type(directory) == "string", "directory (first argument) must be a string if specified")
	assert(
		not condition or type(condition) == "function",
		"condition (second argument) must be a function that returns true or false"
	)

	if not self.active then
		return
	end

	if condition then
		local body = self:GetAsync(directory, query)
		if not condition(body) then
			return
		end
	end

	self:_post(function()
		return HttpService:RequestAsync({
			Url = baseUrl(self.name, directory) .. __privates[self].token,
			Method = "DELETE",
		})
	end)
end

function Firebase:Disable()
	self.active = false
	if self.thread then
		task.cancel(self.thread)
		self.thread = nil
	end
end

function Firebase:Destroy()
	self:Disable()
	Firebase.bases[self.name] = nil
	__privates[self] = nil
	table.clear(self)
end

return Firebase
