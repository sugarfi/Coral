# Enum representing an HTTP status code. *Very* incomplete, using only the most common codes.
enum Status
    Ok = 200
    BadRequest = 400
    NotFound = 404
    NotAllowed = 405
end

# Message for each HTTP code in `Status`.
#
# TODO: add more codes to `Status` and to this hash.
MESSAGES = {
    Status::Ok => "OK",
    Status::BadRequest => "Bad Request",
    Status::NotFound => "Not Found",
    Status::NotAllowed => "Method Not Allowed"
}