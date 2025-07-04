# ---------------------------------------------------------------------------------------------------
# Copyright (c) 2025 by Oliver Bründler
# All rights reserved.
# Authors: Oliver Bruendler
# ---------------------------------------------------------------------------------------------------
import yaml
from pathlib import Path
from fnmatch import fnmatch
from TopLevel import TopLevel

class YamlInterpreter:
    """
    A class to interpret a base YAML file for synthesis tests.
    
    It interprets the YAML describing what files are included and what generics to test with which entity
    configurations. It also matches files based on include and exclude patterns.
    """

    def __init__(self, yaml_file_path):
        """
        Constructor for YamlInterpreter.

        :param yaml_file_path: Path to the base YAML file.
        """
        # Parse the YAML file
        self.data = self._parse_base_yaml(yaml_file_path)

        # Match files
        base_path = Path(yaml_file_path).parent.resolve()
        print(f"Base path: {base_path}")
        include_patterns = self.data["files"]["include"]
        exclude_patterns = self.data["files"]["exclude"]
        self.files =  self._match_files(base_path, include_patterns, exclude_patterns)

    def _parse_base_yaml(self, file_path):
        """
        Private method, not part of the public interface.

        Parses the base.yml file and returns its structured content.

        :param file_path: Path to the base YAML file.
        :return: A dictionary containing the parsed data.
        """
        with open(file_path, 'r') as file:
            data = yaml.safe_load(file)

        # Validate and process the "files" section
        files = data.get("files", {})
        include_patterns = files.get("include", [])
        exclude_patterns = files.get("exclude", [])
        exclude_entities = files.get("exclude_entities", [])

        # Validate and process the "entities" section
        entities = data.get("entities", [])
        parsed_entities = []
        for entity in entities:
            entity_name = entity.get("entity_name")
            fixed_generics = entity.get("fixed_generics", {})
            configurations = entity.get("configurations", [])
            tool_generics = entity.get("tool_generics", {})

            # Process configurations
            parsed_configurations = []
            for config in configurations:
                config_name = config.get("name")
                generics = config.get("generics", {})
                omitted_ports = config.get("omitted_ports", [])
                in_reduce = config.get("in_reduce", {})
                out_reduce = config.get("out_reduce", {})
                parsed_configurations.append({
                    "name": config_name,
                    "generics": generics,
                    "omitted_ports": omitted_ports,
                    "in_reduce": in_reduce,
                    "out_reduce": out_reduce
                })

            # Add parsed entity
            parsed_entities.append({
                "entity_name": entity_name,
                "fixed_generics": fixed_generics,
                "configurations": parsed_configurations,
                "tool_generics": tool_generics
            })
        
        # Get excluded entities
        exclude_entities = data.get("exclude_entities", [])

        return {
            "files": {
                "include": include_patterns,
                "exclude": exclude_patterns
            },
            "entities": parsed_entities,
            "exclude_entities": exclude_entities
        }


    def _match_files(self, base_path, include_patterns, exclude_patterns):
        """
        Matches files based on include and exclude patterns relative to the base path.

        :param base_path: The base path to start searching from.
        :param include_patterns: List of glob patterns to include files.
        :param exclude_patterns: List of glob patterns to exclude files.
        :return: A list of matched file paths.
        """
        base_path = Path(base_path)
        matched_files = []

        for pattern in include_patterns:
            for file in base_path.glob(pattern):
                abs_path = file.absolute().resolve()
                # Check if the file matches any exclude pattern
                if not any(fnmatch(str(abs_path), exclude) for exclude in exclude_patterns):
                    matched_files.append(abs_path)

        return matched_files
    
    @property
    def exclude_entities(self):
        """
        Returns a list of entities that are excluded from the test.
        """
        return self.data.get("exclude_entities", [])
    
    def get_top_levels(self):
        """
        Returns a list of top-level entities from the parsed YAML data.
        """
        top_levels = []
        for entity in self.data["entities"]:
            top = TopLevel(entity["entity_name"])
            # Add fixed generics
            top.add_fix_generics(entity["fixed_generics"])
            # Add tool generics
            for tool, generics in entity["tool_generics"].items():
                top.add_tool_generics(tool, generics)
            # Add configurations
            if not entity["configurations"]:
                # If no configurations, add a default one
                top.add_config("Default", {})
            else:
                for config in entity["configurations"]:
                    top.add_config(config["name"], config["generics"], config["omitted_ports"], config["in_reduce"], config["out_reduce"])
            top_levels.append(top)
        return top_levels
