module fs

# Native implementations are supplied by the Hust Windows runtime.
fn ensure_dir(path: string) -> result<void, FsError>
    return native.fs.ensure_dir(path)
end

# Creates a file only when it does not already exist, preserving user edits.
fn write_new(path: string, content: string) -> result<void, FsError>
    return native.fs.write_new(path, content)
end
