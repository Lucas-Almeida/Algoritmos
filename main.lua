-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

-- Your code here
physics = require("physics")
physics.start()
physics.setDrawMode( "hybrid" )

local backGroup = display.newGroup()
local mainGroup = display.newGroup()
local uiGroup = display.newGroup()

local background = display.newImageRect(backGroup, "forest.png", 570, 350)
background.x = display.contentCenterX
background.y = display.contentCenterY

local tower = display.newImageRect(mainGroup, "tower.png", 50, 100)
tower.x = display.contentCenterX - 200
tower.y = display.contentCenterY + 90
tower.myName = "tower"
tower:scale(3, 2)
physics.addBody(tower, "static")
local towerHp = 3

local floor = display.newImageRect(backGroup, "grass.png", 1200, 20)
floor.x = display.contentCenterX - 300
floor.y = display.contentCenterY + 150
physics.addBody(floor, "static")
floor.myName = "floor"
floor:toBack()

local archer = display.newImageRect(mainGroup, "archer_elf.png", 60, 60)
archer.x = display.contentCenterX - 190
archer.y = display.contentCenterY + 20

local arrow = display.newImageRect(mainGroup, "arrow.png", 20, 20)00
arrow.x, arrow.y = archer.x, archer.y + -14
arrow.rotation = 90
physics.addBody(arrow, "static", {isSensor = true, density = 2, friction = 0.5, bounce = 0.5, radius = arrow.width / 2, filter=arrowCollisionFilter})
arrow.isBullet = true
arrow:toBack()

local arrows = 100 -- ammo count

-- Archer force is set by a player by moving the finger away from the archer
archer.force = 0
archer.forceRadius = 0
-- Minimum and maximum radius of the force circle indicator
local radiusMin, radiusMax = 32, 48
-- Indicates force value
local forceArea = display.newCircle(archer.x, archer.y, radiusMax)
forceArea.strokeWidth = 4
forceArea:setFillColor(1, 0.5, 0.2, 0.2)
forceArea:setStrokeColor(1, 0.5, 0.2)
forceArea.isVisible = false

function archer:touch(event)
    if event.phase == 'began' then
        display.getCurrentStage():setFocus(self, event.id)
        self.isFocused = true
    elseif self.isFocused then
        if event.phase == 'moved' then
            local touchArea = display.newCircle(archer.x, archer.y, radiusMax)
            touchArea.isVisible = true
            touchArea.isHitTestable = false
            touchArea:addEventListener('touch', archer)
            local x, y = self.parent:contentToLocal(event.x, event.y)
            x, y = x - self.x, y - self.y
            local rotation = math.atan2(y, x) * 180 / math.pi + 180
            local radius = math.sqrt(x ^ 2 + y ^ 2)
            self:setForce(radius, rotation)   
            touchArea:removeSelf()   
        else
            display.getCurrentStage():setFocus(self, nil)
            self.isFocused = false
            self:engageForce() 
            forceArea:scale(0, 0)            
        end
    end

    return true
end
archer:addEventListener('touch')

function archer:setForce(radius, rotation)
    self.rotation = rotation % 360 
    if radius > radiusMin then
        if radius > radiusMax then
            radius = radiusMax 
        end
        self.force = radius 
    else
        self.force = 0
    end
    
    forceArea.isVisible = true
    forceArea.xScale = 2 * radius / forceArea.width
    forceArea.yScale = forceArea.xScale
    
    return math.min(radius, radiusMax), self.rotation
end

function archer:engageForce()
    --forceArea.isVisible = false
    self.forceRadius = 0
    if self.force > 0 then
       self:fire()
    end
end

-- arrow functions

function arrow:launch(dir, force)
    if (arrows > 0) then
        local arrow = display.newImageRect("arrow.png", 20, 20)
        arrow.x, arrow.y = archer.x, archer.y + -14
        arrow.rotation = 90
        physics.addBody(arrow, "static", {isSensor = true, density = 2, friction = 0.5, bounce = 0.5, radius = arrow.width / 2})
        arrow.myName = "arrow"
        arrow.isBullet = true
        arrow.angularDamping = 3 -- Prevent the arrow from rolling for too long (necessary?)
        dir = math.rad(dir) -- direction angle in radians
        arrow.bodyType = "dynamic"
        arrow:applyLinearImpulse((force - 30) * math.cos(dir), (force - 30) * math.sin(dir), arrow.x, arrow.y) 
        arrow.isLaunched = true
        arrows = arrows - 1
    end
end

-- fire shit yo

local trajectoryPoints = {} -- White dots along the flying path of a ball

function archer:fire()
    if arrow and not arrow.isLaunched then        
        arrow:launch(archer.rotation, archer.force)
        self:removeTrajectoryPoints()
        self.launchTime = system.getTimer() -- This time value is needed for the trajectory points
        self.lastTrajectoryPointTime = self.launchTime       
        --map:snapCameraTo(self.arrow)
        --sounds.play('cannon')
    end
end

-- Add white trajectory points each time interval
function archer:addTrajectoryPoint()
    local now = system.getTimer()
    -- Draw them for no longer than the first value and each second value millisecods
    if now - self.launchTime < 1000 and now - self.lastTrajectoryPointTime > 85 then
        self.lastTrajectoryPointTime = now
        local point = display.newCircle(self.parent, self.arrow.x, self.arrow.y, 2)
        table.insert(trajectoryPoints, point)
    end
end

-- Clean the trajectory before drawing another one
function archer:removeTrajectoryPoints()
    for i = #trajectoryPoints, 1, -1 do
        table.remove(trajectoryPoints, i):removeSelf()
    end
end

local spawnTimer
local spawnedEnemy = {}

function createEnemy()
    local newEnemy = display.newImageRect(mainGroup, "idle001.png", 20, 55)
    table.insert(spawnedEnemy, newEnemy)
    physics.addBody(newEnemy, "dynamic", {filter=enemyCollisionFilter})
    newEnemy.myName = "orc"
    newEnemy.x = display.contentCenterX + 280
    newEnemy.y = display.contentCenterY + 120
    newEnemy:scale(-3, 1.25)
    newEnemy:setLinearVelocity(10, 0)
    transition.to(newEnemy, {x = -15, time = 17500})
end

function gameLoop()
    createEnemy() 
end

gameLoopTimer = timer.performWithDelay(3000, gameLoop, 0)

function onCollision(event)
    if(event.phase == "began") then
        local obj1 = event.object1
        local obj2 = event.object2 

        if((obj1.myName == "floor" and obj2.myName == "orc") or (obj1.myName == "orc" and obj2.myName == "floor")) then
        
        elseif(obj1.myName == "orc" and obj2.myName == "tower") then
            display.remove(obj1)
        elseif(obj1.myName == "tower" and obj2.myName == "orc") then
            display.remove(obj2)
        elseif((obj1.myName == "orc" and obj2.myName == "arrow") or (obj1.myName == "arrow" and obj2.myName == "orc"))  then
            display.remove(obj1)
            display.remove(obj2)
        end

        for i = #spawnedEnemy, 1, -1 do
            if (spawnedEnemy[i] == obj1 or spawnedEnemy[i] == obj2 ) then
                table.remove(spawnedEnemy, i)
                break
            end
        end       
    end
end

Runtime:addEventListener("collision", onCollision)

-- pássaros carregando flechas
