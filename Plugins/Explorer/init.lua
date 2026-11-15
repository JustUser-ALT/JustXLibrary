-- Explorer plugin package.
-- The current Structure page will be moved here without changing its behavior.
return {
    Manifest = {
        Id = "explorer",
        Name = "Explorer",
        Version = "0.1.0",
        ApiVersion = 1,
    },
    Init = function(context)
        assert(type(context) == "table" and context.Preview, "Explorer requires Preview context")
        return {
            Destroy = function() end,
        }
    end,
}
