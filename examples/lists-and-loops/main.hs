module hustmc.entity.wander

fn step_for(id, tick)
    seed = id * 7 + tick * 13
    dir = seed % 4
    if dir == 0
        return 320
    end
    if dir == 1
        return 0 - 320
    end
    if dir == 2
        return 160
    end
    return 0 - 160
end

fn main()
    mobs = list[101, 102, 103]
    count = mobs.length
    print("tracking mobs:")
    print(count)
    tick = 0
    while tick < 2
        for id in mobs
            step = step_for(id, tick)
            print("tick {tick} mob {id} step {step}")
        end
        tick = tick + 1
    end
    mobs.push(104)
    print("after push:")
    print(mobs.length)
    print(mobs[3])
end
