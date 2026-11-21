package org.ougsi.orchestrator.request;

import java.util.Comparator;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice(assignableTypes = RequestController.class)
class RequestExceptionHandler {
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    RequestError invalidFields(MethodArgumentNotValidException exception) {
        String detail = exception.getBindingResult().getFieldErrors().stream()
                .sorted(Comparator.comparing(FieldError::getField))
                .map(error -> error.getField() + " — " + error.getDefaultMessage())
                .collect(Collectors.joining(", "));
        return RequestError.invalid(detail);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    RequestError unreadableRequest() {
        return RequestError.invalid("Передайте объект JSON с полями заявки допустимых типов.");
    }
}
