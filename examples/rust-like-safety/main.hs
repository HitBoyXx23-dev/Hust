use io
use fs
use async

struct Message
    text: string
end

fn print_message(message: ref Message)
    print(message.text)
end

fn replace_message(message: mut ref Message, text: string)
    message.text = text
end

fn read_message(path: string) -> result<Message, IoError>
    text = fs.read_text(path)?
    return ok(Message(text = text))
end

async fn worker(inbox: channel<Message>)
    while value = await inbox.receive()
        print_message(ref value)
    end
end

fn main() -> result<void, IoError>
    message = read_message("message.txt")?
    print_message(ref message)
    replace_message(mut ref message, "Hust keeps ownership but removes lifetime ceremony")

    shared_message = shared message
    weak_message = weak shared_message

    print(shared_message.text)
    if current = weak_message.upgrade()
        print(current.text)
    end

    return ok()
end
