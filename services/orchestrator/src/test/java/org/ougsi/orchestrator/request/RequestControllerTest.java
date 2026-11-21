package org.ougsi.orchestrator.request;

import java.util.Locale;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(RequestController.class)
class RequestControllerTest {
    private static final String PATH = "/api/v1/requests";
    private static final UUID REQUEST_ID = UUID.fromString("272bcde2-a918-446a-8a32-207e617baa97");
    private static final UUID STEP_ID = UUID.fromString("d3399113-b1e8-4dd6-9527-3108ba827f3c");
    private static final String VALID_BODY = """
            {
              "nodeId": "a4ca2c40-0737-442e-8fd3-d61d4a6281e9",
              "imageId": "dedc125b-a0ed-4b20-9b0e-fc12158ccb17",
              "name": "test-vm",
              "vcpus": 2,
              "memoryMiB": 1024,
              "diskGiB": 8,
              "network": "default"
            }
            """;

    @Autowired
    MockMvc http;

    @MockitoBean
    RequestService requests;

    @Test
    void acceptsValidRequestAndReturnsLocation() throws Exception {
        when(requests.submit(any(CreateVmRequest.class)))
                .thenReturn(new RequestStatus(REQUEST_ID, STEP_ID, "QUEUED"));

        http.perform(post(PATH).contentType(MediaType.APPLICATION_JSON).content(VALID_BODY))
                .andExpect(status().isAccepted())
                .andExpect(header().string("Location", PATH + "/" + REQUEST_ID))
                .andExpect(jsonPath("$.requestId").value(REQUEST_ID.toString()))
                .andExpect(jsonPath("$.stepId").value(STEP_ID.toString()))
                .andExpect(jsonPath("$.status").value("QUEUED"))
                .andExpect(jsonPath("$.result").doesNotExist())
                .andExpect(jsonPath("$.error").doesNotExist());
    }

    @ParameterizedTest
    @MethodSource("invalidRequests")
    void rejectsInvalidRequestBeforeTheServiceIsCalled(String body) throws Exception {
        http.perform(post(PATH).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"))
                .andExpect(jsonPath("$.object").value("request"))
                .andExpect(jsonPath("$.step").value("VM_CREATE"))
                .andExpect(jsonPath("$.detail").isNotEmpty());
        verifyNoInteractions(requests);
    }

    static Stream<String> invalidRequests() {
        return Stream.of(
                "{}",
                VALID_BODY.replace("a4ca2c40-0737-442e-8fd3-d61d4a6281e9", "1-1-1-1-1"),
                VALID_BODY.replace("\"test-vm\"", "\"Uppercase\""),
                VALID_BODY.replace("\"test-vm\"", "123"),
                VALID_BODY.replace("\"test-vm\"", "true"),
                VALID_BODY.replace("\"test-vm\"", "null"),
                VALID_BODY.replace("\"vcpus\": 2", "\"vcpus\": 33"),
                VALID_BODY.replace("\"vcpus\": 2", "\"vcpus\": \"2\""),
                VALID_BODY.replace("\"vcpus\": 2", "\"vcpus\": 2.0"),
                VALID_BODY.replace("\"memoryMiB\": 1024", "\"memoryMiB\": 255"),
                VALID_BODY.replace("\"diskGiB\": 8", "\"diskGiB\": 0"),
                VALID_BODY.replace("\"default\"", "\"-default\""),
                VALID_BODY.replace("{", "{\"unknown\": true,"),
                VALID_BODY.replace("{", "{\"name\":\"another-name\","),
                VALID_BODY + "{}");
    }

    @Test
    void returnsSavedStatusForCanonicalUuidInUppercase() throws Exception {
        when(requests.find(REQUEST_ID)).thenReturn(Optional.of(new RequestStatus(REQUEST_ID, STEP_ID, "QUEUED")));

        http.perform(get(PATH + "/" + REQUEST_ID.toString().toUpperCase(Locale.ROOT)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.requestId").value(REQUEST_ID.toString()))
                .andExpect(jsonPath("$.stepId").value(STEP_ID.toString()))
                .andExpect(jsonPath("$.status").value("QUEUED"));
    }

    @Test
    void rejectsNoncanonicalUuid() throws Exception {
        http.perform(get(PATH + "/1-1-1-1-1"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        verifyNoInteractions(requests);
    }

    @Test
    void reportsMissingRequestWithItsUuid() throws Exception {
        when(requests.find(REQUEST_ID)).thenReturn(Optional.empty());

        http.perform(get(PATH + "/" + REQUEST_ID))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("REQUEST_NOT_FOUND"))
                .andExpect(jsonPath("$.object").value("request/" + REQUEST_ID));
    }
}
