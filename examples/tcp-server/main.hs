use net
fn main()
    listener = TcpListener.bind("0.0.0.0", 8080)
    print("listening on :8080")
    while true
        client = listener.accept()
        spawn handle(client)
    end
end
