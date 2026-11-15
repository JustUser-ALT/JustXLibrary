-- Animation plugin package.
-- The feature implementation will be migrated here from PreviewUI in the next stage.
return {
    Manifest = {
        Id = "animation",
        Name = "Animation",
        Version = "0.1.0",
        ApiVersion = 1,
    },
    Init = function(context)
        assert(type(context) == "table" and context.Preview, "Animation requires Preview context")
        return {
            Destroy = function() end,
        }
    end,
}
