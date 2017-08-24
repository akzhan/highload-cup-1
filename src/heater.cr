require "http/client"

Fiber.sleep(5)

HTTP::Client.get "http://localhost/users/1"
HTTP::Client.get "http://localhost/visits/1"
HTTP::Client.get "http://localhost/locations/1"
