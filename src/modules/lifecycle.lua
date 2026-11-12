-- Lifecycle module factory. Owns tracked resources, async tasks, connections, and tweens.
local function createLifecycleModule(deps)
    local TS = deps.TweenService
    local TweenInfo = deps.TweenInfo
    local Enum = deps.Enum
    local Task = deps.Task
    local Typeof = deps.Typeof
    local PCall = deps.PCall
    local Pack = deps.Pack
    local Unpack = deps.Unpack
    local Error = deps.Error
    local Type = deps.Type
    local Pairs = deps.Pairs
    local IPairs = deps.IPairs
    local IsDisposed = deps.IsDisposed
    local connections = {}
    local resources = {}
    local threads = {}
    local tweens = {}

    local function cleanupResource(resource, cleanup)
        PCall(function()
            if cleanup then cleanup(resource); return end
            local kind = Typeof(resource)
            if kind == "RBXScriptConnection" then resource:Disconnect()
            elseif kind == "Instance" then resource:Destroy()
            elseif kind == "thread" then Task.cancel(resource)
            elseif Type(resource) == "function" then resource()
            elseif Type(resource) == "table" then
                if resource.Destroy then resource:Destroy()
                elseif resource.Disconnect then resource:Disconnect()
                elseif resource.Cancel then resource:Cancel() end
            end
        end)
    end

    local function trackedRunner(record, callback)
        return function(...)
            if IsDisposed() then threads[record] = nil; return end
            local result = Pack(PCall(callback, ...))
            threads[record] = nil
            if not result[1] then Error(result[2], 0) end
            return Unpack(result, 2, result.n)
        end
    end

    local function trackedSpawn(callback, ...)
        if IsDisposed() then return nil end
        local record = {}; threads[record] = true
        record.thread = Task.spawn(trackedRunner(record, callback), ...)
        return record.thread
    end

    local function trackedDelay(seconds, callback, ...)
        if IsDisposed() then return nil end
        local record = {}; threads[record] = true
        record.thread = Task.delay(seconds, trackedRunner(record, callback), ...)
        return record.thread
    end

    local function trackedDefer(callback, ...)
        if IsDisposed() then return nil end
        local record = {}; threads[record] = true
        record.thread = Task.defer(trackedRunner(record, callback), ...)
        return record.thread
    end

    local function keep(connection)
        if connection then connections[#connections + 1] = connection end
        return connection
    end

    local function createTween(...)
        local tween = TS:Create(...)
        local record = {tween = tween}
        tweens[record] = true
        record.connection = tween.Completed:Connect(function()
            tweens[record] = nil
            if record.connection then PCall(function() record.connection:Disconnect() end) end
        end)
        return tween
    end

    local function tw(object, properties, duration, style, direction)
        createTween(object, TweenInfo.new(duration or .2, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out), properties):Play()
    end

    local function cleanupResources()
        for record in Pairs(tweens) do
            tweens[record] = nil
            if record.connection then PCall(function() record.connection:Disconnect() end) end
            if record.tween then
                PCall(function() record.tween:Cancel() end)
                PCall(function() record.tween:Destroy() end)
            end
        end
        for record in Pairs(threads) do
            if record.thread then PCall(Task.cancel, record.thread) end
            threads[record] = nil
        end
        for i = #resources, 1, -1 do
            local item = resources[i]
            resources[i] = nil
            if item then PCall(cleanupResource, item.resource, item.cleanup) end
        end
    end

    return {
        Connections = connections,
        Resources = resources,
        Threads = threads,
        Tweens = tweens,
        CleanupResource = cleanupResource,
        CleanupResources = cleanupResources,
        Keep = keep,
        TrackedSpawn = trackedSpawn,
        TrackedDelay = trackedDelay,
        TrackedDefer = trackedDefer,
        CreateTween = createTween,
        Tween = tw
    }
end
