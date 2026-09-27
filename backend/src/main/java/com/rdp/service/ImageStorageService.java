package com.rdp.service;

import com.rdp.exception.ApiException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import javax.imageio.ImageIO;
import java.io.*;
import java.nio.file.*;
import java.util.Locale;
import java.util.UUID;

@Service
public class ImageStorageService {
    private final Path root;
    public ImageStorageService(@Value("$" + "{app.storage.upload-dir}") String directory) {
        root = Path.of(directory).toAbsolutePath().normalize();
    }
    public String store(MultipartFile file) {
        if (file.isEmpty() || file.getSize() > 8L * 1024 * 1024) throw ApiException.badRequest("Choose an image smaller than 8 MB.");
        try {
            byte[] bytes = file.getBytes();
            if (ImageIO.read(new ByteArrayInputStream(bytes)) == null)
                throw ApiException.badRequest("Only valid PNG or JPEG images are supported.");
            String contentType = file.getContentType() == null ? "" : file.getContentType().toLowerCase(Locale.ROOT);
            String extension = contentType.equals("image/png") ? ".png" : contentType.equals("image/jpeg") ? ".jpg" : null;
            if (extension == null) throw ApiException.badRequest("Only PNG and JPEG images are supported.");
            Files.createDirectories(root);
            String name = UUID.randomUUID() + extension;
            Files.write(root.resolve(name), bytes, StandardOpenOption.CREATE_NEW);
            return "/api/uploads/" + name;
        } catch (IOException ex) {
            throw new ApiException(org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR, "The image could not be saved.");
        }
    }
    public Path resolve(String filename) {
        if (filename == null || !filename.matches("[a-f0-9-]{36}\\.(png|jpg)")) throw ApiException.notFound("Image not found.");
        Path path = root.resolve(filename).normalize();
        if (!path.startsWith(root)) throw ApiException.notFound("Image not found.");
        return path;
    }
}
