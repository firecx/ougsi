package org.ougsi.orchestrator.request;

import java.util.UUID;

record RequestError(String code, String object, String step, String detail) {
    private static final String STEP = "VM_CREATE";

    static RequestError invalid(String detail) {
        return new RequestError("INVALID_REQUEST", "request", STEP, detail);
    }

    static RequestError notFound(UUID requestId) {
        return new RequestError("REQUEST_NOT_FOUND", "request/" + requestId, STEP, "Заявка не найдена.");
    }
}
