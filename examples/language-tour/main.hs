module demo

fn add(a, b)
    return a + b
end

fn fib(n)
    if n < 2
        return n
    end
    return fib(n - 1) + fib(n - 2)
end

fn greet(name)
    return "hello " + name
end

fn main()
    x = 7
    y = add(x, 5)
    print("x = {x}, y = {y}")
    print(greet("HitBoy"))
    i = 0
    total = 0
    while i < 5
        total = total + i * i
        i = i + 1
    end
    print("sum of squares = {total}")
    print("fib(12) = ")
    print(fib(12))
    if total > 20 and x == 7
        print("branch taken")
    else
        print("branch missed")
    end
end
