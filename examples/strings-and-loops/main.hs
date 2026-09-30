fn main()
    name = "hust"
    if name == "hust"
        print("string equality works")
    end
    if name != "rust"
        print("string inequality works")
    end
    ids = list[1, 2, 3, 4, 5]
    total = 0
    for id in ids
        if id == 3
            continue
        end
        if id == 5
            break
        end
        total = total + id
    end
    print("total skipping 3 and stopping at 5:")
    print(total)
end
