package org.ougsi.orchestrator.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

record CreateVmRequest(
        @NotNull(message = "укажите идентификатор узла")
        @Pattern(regexp = UUID_FORMAT, message = "укажите UUID узла")
        String nodeId,

        @NotNull(message = "укажите идентификатор образа")
        @Pattern(regexp = UUID_FORMAT, message = "укажите UUID образа")
        String imageId,

        @NotNull(message = "укажите имя ВМ")
        @Pattern(regexp = DNS_LABEL, message = "используйте DNS-метку длиной от 1 до 63 символов в нижнем регистре")
        String name,

        @NotNull(message = "укажите число виртуальных процессоров")
        @Min(value = 1, message = "укажите число от 1 до 32")
        @Max(value = 32, message = "укажите число от 1 до 32")
        Integer vcpus,

        @NotNull(message = "укажите объём памяти в МиБ")
        @Min(value = 256, message = "укажите объём памяти от 256 до 131072 МиБ")
        @Max(value = 131072, message = "укажите объём памяти от 256 до 131072 МиБ")
        Integer memoryMiB,

        @NotNull(message = "укажите размер диска в ГиБ")
        @Min(value = 1, message = "укажите размер диска от 1 до 2048 ГиБ")
        @Max(value = 2048, message = "укажите размер диска от 1 до 2048 ГиБ")
        Integer diskGiB,

        @NotNull(message = "укажите имя сети")
        @Pattern(regexp = DNS_LABEL, message = "используйте DNS-метку длиной от 1 до 63 символов в нижнем регистре")
        String network) {

    static final String UUID_FORMAT = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}";
    private static final String DNS_LABEL = "[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?";
}
