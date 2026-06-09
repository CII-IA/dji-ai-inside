from setuptools import setup, find_packages

setup(
    name='dji-ai-inside',
    version='0.1.0',
    description='mmyolo v0.6.0 + mmseg b040e147 patched for DJI AI Inside NPU',
    packages=find_packages(include=['dji_ai_inside']),
    python_requires='>=3.10',
)
