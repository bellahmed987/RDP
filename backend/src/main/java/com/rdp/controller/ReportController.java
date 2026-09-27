package com.rdp.controller;

import com.rdp.dto.ApiDtos.*;
import com.rdp.entity.ReportStatus;
import com.rdp.service.ReportService;
import jakarta.validation.Valid;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api")
public class ReportController {
    private final ReportService reports;
    public ReportController(ReportService reports) { this.reports = reports; }
    @PostMapping("/reports") public ResponseEntity<ReportView> create(Authentication auth, @Valid @RequestBody ReportInput input) {
        return ResponseEntity.status(HttpStatus.CREATED).body(reports.create(auth.getName(), input));
    }
    @GetMapping("/admin/reports") @PreAuthorize("hasRole('ADMIN')")
    public List<ReportView> all() { return reports.all(); }
    @PatchMapping("/admin/reports/{id}") @PreAuthorize("hasRole('ADMIN')")
    public ReportView update(@PathVariable Long id, @RequestParam ReportStatus status) { return reports.update(id, status); }
}
