package org.ougsi.orchestrator.request;

import java.util.UUID;

record RequestStatus(UUID requestId, UUID stepId, String status) {}
