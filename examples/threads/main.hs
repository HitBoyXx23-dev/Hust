fn main()
    for i in 0..8
        spawn print("worker {i}")
    end
end
