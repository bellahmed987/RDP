package com.rdp.controller;

import com.rdp.service.ImageStorageService;
import org.springframework.core.io.*;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.io.IOException;
import java.nio.file.*;

@RestController
@RequestMapping("/api/uploads")
public class UploadController {
    private final ImageStorageService storage;
    public UploadController(ImageStorageService storage) { this.storage = storage; }
    @GetMapping("/{filename}")
    public ResponseEntity<Resource> get(@PathVariable String filename) throws IOException {
        Path path = storage.resolve(filename);
        if (!Files.exists(path)) return ResponseEntity.notFound().build();
        MediaType type = filename.endsWith(".png") ? MediaType.IMAGE_PNG : MediaType.IMAGE_JPEG;
        return ResponseEntity.ok().contentType(type).cacheControl(CacheControl.maxAge(java.time.Duration.ofDays(7)))
                .body(new FileSystemResource(path));
    }
}
