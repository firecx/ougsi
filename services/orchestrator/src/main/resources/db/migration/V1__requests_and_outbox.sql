CREATE TABLE orchestrator.request (
    request_id uuid PRIMARY KEY,
    node_id uuid NOT NULL,
    image_id uuid NOT NULL,
    status text NOT NULL CHECK (status IN ('QUEUED', 'SUCCEEDED', 'FAILED')),
    specification jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orchestrator.request_step (
    step_id uuid PRIMARY KEY,
    request_id uuid NOT NULL REFERENCES orchestrator.request (request_id),
    operation text NOT NULL,
    status text NOT NULL CHECK (status IN ('QUEUED', 'SUCCEEDED', 'FAILED')),
    UNIQUE (request_id, operation)
);

CREATE TABLE orchestrator.outbox (
    step_id uuid PRIMARY KEY REFERENCES orchestrator.request_step (step_id),
    routing_key text NOT NULL,
    payload jsonb NOT NULL,
    state text NOT NULL DEFAULT 'PENDING' CHECK (state IN ('PENDING', 'PUBLISHED')),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
