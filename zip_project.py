import os
import zipfile

def zip_folder(folder_path, output_path):
    exclude_dirs = {
        'build', '.dart_tool', '.gradle', 'venv', '.git', 
        '__pycache__', '.idea', '.vscode'
    }
    
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(folder_path):
            # Prune excluded directories
            dirs[:] = [d for d in dirs if d not in exclude_dirs]
            
            for file in files:
                if file.endswith('.zip') or file == 'zip_project.py': continue
                
                try:
                    file_path = os.path.join(root, file)
                    # Check if path is valid
                    if not os.path.isfile(file_path): continue
                    
                    arcname = os.path.relpath(file_path, folder_path)
                    zipf.write(file_path, arcname)
                except Exception as e:
                    print(f"Skipping {file}: {e}")
    
    print(f"Successfully created: {output_path}")

if __name__ == "__main__":
    zip_folder('.', 'GymAI_Master_Package.zip')
