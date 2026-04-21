# Error handling for QdrantClient.jl

"""
    QdrantError <: Exception

Error type for Qdrant API failures.

# Fields
- `status::Int`: HTTP status code
- `message::String`: Human-readable error message
- `detail::Any`: Additional error details (parsed from API response)
- `source::Union{HTTP.Exception, Nothing}`: Original HTTP exception if any
"""
struct QdrantError <: Exception
    status::Int
    message::String
    detail::Any
    source::Union{HTTP.Exception, Nothing}
end

function Base.showerror(io::IO, err::QdrantError)
    print(io, "QdrantError: ")
    if err.status != 0
        print(io, "[HTTP $(err.status)] ")
    end
    print(io, err.message)
    if err.detail !== nothing
        print(io, "\n  Detail: ", err.detail)
    end
    if err.source !== nothing
        print(io, "\n  Source: ")
        showerror(io, err.source)
    end
end

"""
    qdrant_error(status::Int, message::String, detail=nothing, source=nothing)

Create a QdrantError with the given parameters.
"""
function qdrant_error(status::Int, message::String, detail=nothing, source=nothing)
    return QdrantError(status, message, detail, source)
end

"""
    http_to_qdrant_error(http_exception::HTTP.Exception)

Convert an HTTP exception to a QdrantError.
"""
function http_to_qdrant_error(http_exception::HTTP.Exception)
    # Extract status code from HTTP exception if possible
    status = 0
    message = "HTTP request failed"

    if http_exception isa HTTP.StatusError
        status = http_exception.status
        message = "HTTP $status: $(http_exception.response.status)"
    end

    return QdrantError(status, message, nothing, http_exception)
end

"""
    api_error_response(response::HTTP.Response)

Create a QdrantError from an API error response.

Qdrant API returns errors in the format:
```json
{
  "time": 0.001,
  "status": {
    "error": "Description of the occurred error."
  },
  "result": null
}
```
"""
function api_error_response(response::HTTP.Response)
    status = response.status
    body = String(response.body)

    # Try to parse error details from response body
    detail = nothing
    message = "API error $(status)"

    try
        parsed = JSON.parse(body; dicttype=Dict{Symbol, Any})
        if haskey(parsed, :status) && parsed[:status] isa Dict && haskey(parsed[:status], :error)
            message = parsed[:status][:error]
            detail = parsed
        else
            detail = parsed
            message = "API error $(status): $(body[1:min(100, end)])..."
        end
    catch e
        # If we can't parse the JSON, use the raw body
        detail = body
        message = "API error $(status): $(body[1:min(100, end)])..."
    end

    return QdrantError(status, message, detail, nothing)
end

"""
    check_response!(response::HTTP.Response)

Check an HTTP response and throw a QdrantError if it's not successful.

Returns the response if successful.
"""
function check_response!(response::HTTP.Response)
    if response.status >= 400
        throw(api_error_response(response))
    end
    return response
end

"""
    wrap_http_errors(f::Function)

Wrap a function that makes HTTP requests, converting HTTP exceptions to QdrantError.
"""
function wrap_http_errors(f::Function)
    try
        return f()
    catch e
        if e isa HTTP.Exception
            throw(http_to_qdrant_error(e))
        else
            rethrow(e)
        end
    end
end