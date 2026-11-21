package org.ougsi.orchestrator.request;

import java.net.URI;
import java.util.UUID;
import java.util.regex.Pattern;

import jakarta.validation.Valid;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(path = RequestController.PATH, produces = MediaType.APPLICATION_JSON_VALUE)
class RequestController {
    static final String PATH = "/api/v1/requests";
    private static final Pattern UUID_PATTERN = Pattern.compile(CreateVmRequest.UUID_FORMAT);

    private final RequestService requests;

    RequestController(RequestService requests) {
        this.requests = requests;
    }

    @PostMapping(consumes = MediaType.APPLICATION_JSON_VALUE)
    ResponseEntity<RequestStatus> submit(@Valid @RequestBody CreateVmRequest request) {
        RequestStatus status = requests.submit(request);
        URI location = URI.create(PATH + "/" + status.requestId());
        return ResponseEntity.accepted().location(location).body(status);
    }

    @GetMapping("/{requestId}")
    ResponseEntity<?> find(@PathVariable String requestId) {
        if (!UUID_PATTERN.matcher(requestId).matches()) {
            return ResponseEntity.badRequest().body(RequestError.invalid("Укажите UUID заявки."));
        }

        UUID id = UUID.fromString(requestId);
        return requests.find(id)
                .<ResponseEntity<?>>map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.status(404).body(RequestError.notFound(id)));
    }
}
