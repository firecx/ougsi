package org.ougsi.orchestrator.request;

import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ObjectNode;

@Service
class RequestService {
    private static final String QUEUED = "QUEUED";
    private static final String VM_CREATE = "vm.create";

    private final JdbcClient jdbc;
    private final ObjectMapper json;

    RequestService(JdbcClient jdbc, ObjectMapper json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    @Transactional
    public RequestStatus submit(CreateVmRequest request) {
        UUID requestId = UUID.randomUUID();
        UUID stepId = UUID.randomUUID();
        UUID nodeId = UUID.fromString(request.nodeId());
        UUID imageId = UUID.fromString(request.imageId());

        jdbc.sql("""
                INSERT INTO orchestrator.request (request_id, node_id, image_id, status, specification)
                VALUES (?, ?, ?, ?, CAST(? AS jsonb))
                """)
                .params(requestId, nodeId, imageId, QUEUED, json.writeValueAsString(request))
                .update();

        jdbc.sql("""
                INSERT INTO orchestrator.request_step (step_id, request_id, operation, status)
                VALUES (?, ?, ?, ?)
                """)
                .params(stepId, requestId, VM_CREATE, QUEUED)
                .update();

        ObjectNode event = json.valueToTree(request);
        event.put("schemaVersion", 1);
        event.put("requestId", requestId.toString());
        event.put("stepId", stepId.toString());
        event.put("nodeId", nodeId.toString());
        event.put("imageId", imageId.toString());
        event.put("operation", VM_CREATE);
        jdbc.sql("""
                INSERT INTO orchestrator.outbox (step_id, routing_key, payload)
                VALUES (?, ?, CAST(? AS jsonb))
                """)
                .params(stepId, VM_CREATE, json.writeValueAsString(event))
                .update();

        return new RequestStatus(requestId, stepId, QUEUED);
    }

    public Optional<RequestStatus> find(UUID requestId) {
        return jdbc.sql("""
                SELECT request.request_id, request_step.step_id, request.status
                FROM orchestrator.request
                JOIN orchestrator.request_step USING (request_id)
                WHERE request.request_id = ? AND request_step.operation = ?
                """)
                .params(requestId, VM_CREATE)
                .query((rs, row) -> new RequestStatus(
                        rs.getObject("request_id", UUID.class),
                        rs.getObject("step_id", UUID.class),
                        rs.getString("status")))
                .optional();
    }
}
