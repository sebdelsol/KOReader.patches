local AlphaContainer = require("ui/widget/container/alphacontainer")
local BD = require("ui/bidi")
local BottomContainer = require("ui/widget/container/bottomcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local ImageWidget = require("ui/widget/imagewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local userpatch = require("userpatch")

-- local logger = require("logger")

local function capitalize(sentence)
    local words = {}
    for word in sentence:gmatch("%S+") do
        table.insert(words, word:sub(1, 1):upper() .. word:sub(2):lower())
    end
    return table.concat(words, " ")
end

local function getAlphaFrame(border_size, alpha, widget)
    return FrameContainer:new {
        padding = 0,
        bordersize = border_size,
        AlphaContainer:new { alpha = alpha, widget },
    }
end

local function patchCoverbrowser(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    local BookInfoManager = userpatch.getUpValue(MosaicMenuItem.update, "BookInfoManager")
    local original_update = MosaicMenuItem.update

    function MosaicMenuItem:update(...)
        original_update(self, ...)
        if self._foldercover_processed or self.menu.no_refresh_covers or not self.do_cover_image then
            return
        end

        if self.entry.is_file or self.entry.file then return end -- it's a file

        local dir_path = self.entry and self.entry.path
        if not dir_path then return end

        self.menu._dummy = true
        local entries = self.menu:genItemTableFromPath(dir_path) -- sorted
        self.menu._dummy = false
        if not entries then return end

        for _, entry in ipairs(entries) do
            local bookinfo = BookInfoManager:getBookInfo(entry.path, true)
            local widget = self:_getFolderCover(bookinfo)
            if widget then
                if self._underline_container[1] then self._underline_container[1]:free(true) end
                self._underline_container[1] = widget
                self._foldercover_processed = true
                break
            end
        end
    end

    function MosaicMenuItem:_getFolderCover(bookinfo)
        if
            bookinfo
            and bookinfo.has_cover
            and bookinfo.cover_fetched
            and not bookinfo.ignore_cover
            and not BookInfoManager.isCachedCoverInvalid(bookinfo, self.menu.cover_specs)
        then
            local border_size = Size.border.thick
            local alpha = 0.75

            local _, _, scale_factor = BookInfoManager.getCachedCoverSize(
                bookinfo.cover_w,
                bookinfo.cover_h,
                self.width - 2 * border_size,
                self.height - 2 * border_size
            )
            local image = ImageWidget:new { image = bookinfo.cover_bb, scale_factor = scale_factor }
            image:_render()
            local img_size = image:getSize()
            local dimen = { w = img_size.w + 2 * border_size, h = img_size.h + 2 * border_size }
            local directory, nbitems = self:_getTextBoxes { w = img_size.w, h = img_size.h }

            return CenterContainer:new {
                dimen = { w = self.width, h = self.height },
                OverlapGroup:new {
                    dimen = dimen,
                    FrameContainer:new { padding = 0, bordersize = border_size, image },
                    CenterContainer:new { dimen = dimen, getAlphaFrame(border_size, alpha, directory) },
                    BottomContainer:new { dimen = dimen, getAlphaFrame(border_size, alpha, nbitems) },
                },
            }
        end
    end

    function MosaicMenuItem:_getTextBoxes(dimen)
        local nbitems = TextBoxWidget:new {
            text = self.mandatory,
            face = Font:getFace("cfont", 17),
            width = dimen.w,
            alignment = "center",
        }

        local text = self.text
        if text:match("/$") then text = text:sub(1, -2) end -- remove "/"
        text = BD.directory(capitalize(text))
        local available_height = dimen.h - 2 * nbitems:getSize().h
        local dir_font_size = 25
        local directory

        while true do
            if directory then directory:free(true) end
            directory = TextBoxWidget:new {
                text = text,
                face = Font:getFace("cfont", dir_font_size),
                width = dimen.w,
                alignment = "center",
                bold = true,
            }
            if directory:getSize().h <= available_height then break end
            dir_font_size = dir_font_size - 1
            if dir_font_size < 10 then -- don't go too low
                directory:free()
                directory.height = available_height
                directory.height_adjust = true
                directory.height_overflow_show_ellipsis = true
                directory:init()
                break
            end
        end

        return directory, nbitems
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverbrowser)
