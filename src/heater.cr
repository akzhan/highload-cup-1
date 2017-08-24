require "http/client"

Fiber.sleep(5)

HTTP::Client.get "http://localhost/users/1"
HTTP::Client.get "http://localhost/locations/1"
HTTP::Client.get "http://localhost/visits/1"

HTTP::Client.post "http://localhost/users/1", nil, body: "{}"
HTTP::Client.post "http://localhost/locations/1", nil, body: "{}"
HTTP::Client.post "http://localhost/visits/1", nil, body: "{}"
