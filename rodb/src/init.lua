local RoDB = {}
RoDB.__index = RoDB

-- Getting Services
local DataBaseService = game:GetService("DataStoreService")
local rednet = require(script:WaitForChild("rednet"))
local tidy = require(script:WaitForChild("tidy"))

type ProfileId = string | number
type Database = string | number;

type Profile = typeof(RoDB.createProfile())

function createSymbol(name)
    local _blank_data = newproxy(true)

    getmetatable(_blank_data).__tostring = function()
        return ("Key(%s)"):format(name)
    end

    return _blank_data;
end

type Table = {[any]: any}

function reconcileTable(template: Table, data: Table)
    for i, v in pairs(template) do
        if data[i] == nil then
            data[i] = v
        end
    end
end

function RoDB.createProfile(Name: Database, Id: ProfileId, template: Table)
    local cleanUp = tidy.init()
    local profile = {
        _cleanup = cleanUp,
        data = {},
        Id = Id,
        template =  {},
        database = DataBaseService:GetDataStore(Name),
        isOpened = true,
        saving = cleanUp:add(rednet.createSignal()),
        reconciled = cleanUp:add(rednet.createSignal()),
    }

    local self = setmetatable(profile, RoDB)
    self:__createTemplate(template)

    -- This adds the template to the template table within the profile
    return self
end

function RoDB:__createTemplate(template)

    if type(template) ~= "table" then
        warn(`must use a table; {debug.traceback()}`)
    end

    self.template = template
end

function RoDB:RunFunctionWhenClosing(func)
    if type(func) == "function" then
        self._cleanup:add(func)
    end
end

function RoDB:Save()

    local function saveData(oldData)
        if oldData == nil then
            oldData = {}
        end
    
        for i, v in pairs(self.data) do
            oldData[i] = v
        end
    
        return oldData
    end

    local success, err = pcall(self.database.UpdateAsync, self.database, self.Id, saveData)

    if success then
        self.saving:Fire(self.Id)
    else
        warn(err)
    end

end

function RoDB:Get()
    local success, data = pcall(function()
        return self.database:GetAsync(self.Id)
    end)

    if success then

        if data == nil then
            data = {}
        end

        for i, v in pairs(data) do
            self.data[i] = v
        end
    end

    -- This returns a cloned frozen version of the data
    return table.freeze(table.clone(self.data))
end

function RoDB:Reconcile()
    -- This compares the template to the actual data and fills in the missing spaces
    reconcileTable(self.template, self.data)
    self.reconciled:Fire(self.Id)
end

function RoDB:CloseProfile()
    if self.isOpened ~= true then
        return
    end

    self.data = nil
    self.template = nil
    task.wait(1)
    self._cleanup:Clean()  -- Executes functions and clean objects and events.
end

return RoDB